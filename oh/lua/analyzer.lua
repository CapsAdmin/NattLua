local types = require("oh.typesystem.types")
types.Initialize()

local META = {}
META.__index = META

require("oh.base_analyzer")(META)

function META:SetOperator(obj, key, val, node)
    
    if obj.Type == "set" then
        -- local x: nil | {foo = true}
        -- print(x.foo) << error because nil cannot be indexed, to continue we have to remove nil from the set
        -- print(x.foo) << no error, because now x does not contain nil
        
        local new_set = types.Set()
        local truthy_set = types.Set()
        local falsy_set = types.Set()

        for _, v in ipairs(obj:GetTypes()) do
            local ok, err = self:SetOperator(v, key, val, node)

            if ok then
                truthy_set:AddType(v)
                new_set:AddType(v)
            else
                falsy_set:AddType(v)
                
                self:Report(node, err or "invalid set error")

                self:CloneCurrentScope()
                self:GetScope().test_condition = obj
            end            
        end

        new_set.truthy_set = truthy_set
        new_set.falsy_set = falsy_set

        return new_set:SetSource(node, new_set, obj)
    end

    if obj.meta then
        local func = obj.meta:Get("__newindex")

        if func then
            if func.Type == "table" then
                return func:Set(key, val)
            end

            if func.Type == "function" then
                return self:Call(func, types.Tuple({obj, key, val}), key.node)
            end
        end
    end

    -- local obj: {string = number}
    -- obj.foo = 1
    -- print(obj.foo) << since the contract states that key is a string, then obj.foo would be nil or a number
    -- this adds some additional context
    obj.last_set = obj.last_set or {}
    obj.last_set[key] = val

    return obj:Set(key, val)
end

function META:GetOperator(obj, key, node)
    if obj.Type == "set" then
        local copy = types.Set()
        for _,v in ipairs(obj:GetTypes()) do
            local val, err = self:GetOperator(v, key, node)
            if not val then
                return val, err
            end
            copy:AddType(val)
        end
        return copy
    end

    if obj.Type ~= "table" and obj.Type ~= "tuple" and obj.Type ~= "list" and (obj.Type ~= "string") then
        return obj:Get(key)
    end
    
    if obj.meta and (obj.Type ~= "table" or not obj:Contains(key)) then
        local index = obj.meta:Get("__index")

        if index then
            if index.Type == "table" then
                return self:GetOperator(index.contract or index, key, node)
            end

            if index.Type == "function" then
                local obj, err = self:Call(index, types.Tuple({obj, key}), key.node)
                
                if not obj then
                    return obj, err
                end

                return obj:Get(1)
            end
        end
    end
    
    if obj.contract then
        return obj:Get(key)
    end

    -- local obj: {string = number}
    -- obj.foo = 1
    -- print(obj.foo) << since the contract states that key is a string, then obj.foo would be nil or a number
    -- this adds some additional context
    if obj.last_set and not key:IsLiteral() and obj.last_set[key] then
        return obj.last_set[key]
    end

    local val, err = obj:Get(key)

    if not val then
        return self:NewType(node or obj.node, "nil")
    end

    return val
end

function META:NewType(node, type, data, literal, parent)
    local obj

    if type == "table" then
        obj = self:Assert(node, types.Table(data))
    elseif type == "list" then
        obj = self:Assert(node, types.List(data))
    elseif type == "..." then
        if not data then
            obj = self:Assert(node, types.Tuple({}):SetElementType(types.Any()):Max(math.huge))
        else
            obj = self:Assert(node, types.Tuple(data))
            obj:Max(math.huge)
        end
    elseif type == "number" then
        obj = self:Assert(node, types.Number(data):MakeLiteral(literal))
    elseif type == "string" then
        obj = self:Assert(node, types.String(data):MakeLiteral(literal))
    elseif type == "boolean" then
        if literal then
            obj = types.Symbol(data)
        else
            obj = types.Boolean:Copy()
        end
    elseif type == "nil" then
        obj = self:Assert(node, types.Symbol(nil))
    elseif type == "any" then
        obj = self:Assert(node, types.Any())
    elseif type == "never" then
        obj = self:Assert(node, types.Never())
    elseif type == "error" then
        obj = self:Assert(node, types.Error(data))
    elseif type == "function" then
        obj = self:Assert(node, types.Function(data))
        obj.node = node

        if node.statements then 
            obj.function_body_node = node
        end
    end

    if not obj then error("NYI: " .. type) end

    obj.node = obj.node or node
    obj.node.inferred_type = obj
    node.scope = self.scope -- move this out of here

    return obj
end

do
    local guesses = {
        {pattern = "count", type = "number"},
        {pattern = "tbl", type = "table", ctor = function(obj) obj:Set(types.Any(), types.Any()) end},
        {pattern = "str", type = "string"},
    }

    table.sort(guesses, function(a, b) return #a.pattern > #b.pattern end)

    function META:GuessTypeFromIdentifier(node, env)

        if node.value then
            local str = node.value.value:lower()

            for _, v in ipairs(guesses) do
                if str:find(v.pattern, nil, true) then
                    local obj = self:NewType(node, v.type)
                    if v.ctor then
                        v.ctor(obj)
                    end
                    return obj
                end
            end
        end

        if env == "typesystem" then
            return self:NewType(node, "nil")
        end

        return self:NewType(node, "any")
    end
end

function META:LuaTypesToTuple(node, tps)
    local tbl = {}
    
    for i,v in ipairs(tps) do
        if types.IsTypeObject(v) then
            tbl[i] = v
        else
            if type(v) == "function" then
                tbl[i] = self:NewType(node, "function", {lua_function = v, arg = types.Tuple(), ret = types.Tuple()}, true)
            else
                tbl[i] = self:NewType(node, type(v), v, true)
            end
        end
    end

    if tbl[1] and tbl[1].Type == "tuple" and #tbl == 1 then
        return tbl[1]
    end

    return types.Tuple(tbl)
end

function META:AnalyzeFunctionBody(function_node, arguments, env)
    self:PushScope(function_node)
    self:PushEnvironment(function_node, nil, env)

    if function_node.self_call then
        self:CreateLocalValue("self", arguments:Get(1) or self:NewType(function_node, "nil"), env)
    end

    for i, identifier in ipairs(function_node.identifiers) do
        local argi = function_node.self_call and (i+1) or i

        if identifier.value.value == "..." then
            local values = {}
            for i = argi, arguments:GetLength() do
                table.insert(values, arguments:Get(i))
            end
            self:CreateLocalValue(identifier, self:NewType(identifier, "...", values), env)
        else
            self:CreateLocalValue(identifier, arguments:Get(argi) or self:NewType(identifier, "nil"), env)
        end
    end

    self:ReturnToThisScope()
    self:PushReturn()
    local analyzed_return = self:AnalyzeStatementsAndCollectReturnTypes(function_node)

    self:PopEnvironment(env)
    self:PopScope()

    self.returned_from_block = nil

    return analyzed_return
end

function META:Call(obj, arguments, call_node)
    call_node = call_node or obj.node
    local function_node = obj.function_body_node or obj.node

    obj.called = true

    self.call_stack = self.call_stack or {}

    table.insert(self.call_stack, {
        func = obj.node,
        call_expression = call_node
    })

    local env = self.PreferTypesystem and "typesystem" or "runtime"

    if obj.Type == "set" then
        local new_set = types.Set()
        local truthy_set = types.Set()
        local falsy_set = types.Set()

        for _, v in ipairs(obj:GetData()) do               
            if v.Type ~= "function" and v.Type ~= "table" and v.Type ~= "any" then
                falsy_set:AddType(v)

                self:Report(call_node, "set "..tostring(obj).." contains uncallable object " .. tostring(v))

                self:CloneCurrentScope()
                self:GetScope().test_condition = obj
            else
                truthy_set:AddType(v)
                new_set:AddType(v)
            end
        end

        new_set.truthy_set = truthy_set
        new_set.falsy_set = falsy_set

        obj = truthy_set:SetSource(node, new_set, obj)
    end

    if obj.Type ~= "function" then
        return obj:Call(self, arguments, call_node)
    end

    local ok, err = obj:CheckArguments(arguments)

    if not ok then
        return ok, err
    end

    if self.OnFunctionCall then
        self:OnFunctionCall(obj, arguments)
    end

    if obj.data.lua_function then
        local res = {self:CallLuaTypeFunction(call_node, obj.data.lua_function, arguments:Unpack())}
        
        return self:LuaTypesToTuple(obj.node, res)
    elseif not function_node or function_node.kind == "type_function" then
        self:FireEvent("external_call", call_node, obj)
    else
        if not function_node.statements then
            return types.errors.other("cannot call "..tostring(function_node:Render()).." because it has no statements")
        end

        do -- recursive guard
            obj.call_count = obj.call_count or 0
            if obj.call_count > 10 or debug.getinfo(30) then
                local ret = obj:GetReturnTypes()
                if ret and ret:Get(1) then
                    return types.Tuple({ret:Get(1)})
                end
                return types.Tuple({self:NewType(call_node, "any")})
            end
            obj.call_count = obj.call_count + 1
        end

        local arguments = arguments

        if 
            obj.explicit_arguments and 
            env ~= "typesystem" and 
            function_node.kind ~= "local_generics_type_function" and 
            not call_node.type_call
        then
            arguments = obj:GetArguments()
        end

        local return_tuple = self:AnalyzeFunctionBody(function_node, arguments, env)
            
        do
            -- if this function has an explicit return type
            if function_node.return_types then
                local ok, reason = return_tuple:SubsetOf(obj:GetReturnTypes())
                if not ok then
                    return ok, reason
                end
            else
                -- copy the entire tuple so we don't modify the return value of this call
                obj:GetReturnTypes():Merge(return_tuple)
            end
        end

        obj:GetArguments():Merge(arguments)

        self:FireEvent("function_spec", obj)

        -- this is so that the return type of a function can access its arguments, to generics
        -- local function foo(a: number, b: number): Foo(a, b) return a + b end
        if function_node.return_types then
            self:PushScope(function_node)
                for i, key in ipairs(function_node.identifiers) do
                    self:CreateLocalValue(key, arguments:Get(i), "typesystem")
                end

                for i, type_exp in ipairs(function_node.return_types) do
                    return_tuple:Set(i, self:AnalyzeExpression(type_exp, "typesystem"))
                end
            self:PopScope()
        end

        do -- this is for the emitter
            if function_node.identifiers then
                for i, node in ipairs(function_node.identifiers) do
                    node.inferred_type = obj:GetArguments():Get(i)
                end
            end

            function_node.inferred_type = obj
        end

        return return_tuple
    end

    return obj:GetReturnTypes():Copy():SetReferenceId(nil)
end

do -- control flow analysis

    -- this turns out to be really hard so I'm trying 
    -- to isolate the code for this here and do 
    -- naive approaches while writing tests

    function META:OnEnterScope(kind, data)
        local scope = self:GetScope()

        scope.test_condition = data.condition

        if data.is_else then
            scope.test_condition_inverted = true
        end

        if data.condition:IsUncertain() then
            scope.uncertain = true
        end
    end

    function META:MakeUncertainDataOutsideInParentScopes()
        for _, obj in ipairs(self:GetScope().upvalues.runtime.list) do
            if obj.data_outside_of_if_blocks then
               obj.data = obj.data_outside_of_if_blocks
               obj.data_outside_of_if_blocks = nil
            end
        end
    end

    function META:OnFunctionCall(obj, arguments)
        for i = 1, arguments:GetLength() do
            local arg = obj:GetArguments():Get(i)
            if arg and arg.out then
                local upvalue = arguments:Get(i).upvalue
                if upvalue then
                    self:SetEnvironmentValue(upvalue.key, arguments:Get(i):Copy():MakeUnique(true), "runtime")
                end
            end
        end
    end

    function META:OnExitScope(kind, data)
        local scope = self:GetLastScope()

        if self.returned_from_block or self.lua_error_thrown then
            if scope.uncertain then           
                self:CloneCurrentScope()

                self:GetScope().uncertain = true
                self:GetScope().test_condition = scope.test_condition
                self:GetScope().test_condition_inverted = true
            else
                self:CloneCurrentScope()

                self:GetScope().unreachable = true
            end
        end
        
        if kind ~= "if" then
            self:MakeUncertainDataOutsideInParentScopes()
        end
    end

    function META:OnLeaveIfStatement()
        -- this has to be done after all if blocks have been processed
        self:MakeUncertainDataOutsideInParentScopes()
    end
    
    function META:OnEnterNumericForLoop(scope, init, max)
        if not init:IsLiteral() or not max:IsLiteral() then
            scope.uncertain = true
        end
    end

    function META:OnFindLocalValue(upvalue, key, env, scope)
        if self:GetScope().unreachable then
      --      return self:CopyUpvalue(upvalue, types.Never())
        end
        
        if upvalue.data.Type == "set" then
            local condition = scope.test_condition
            
            if condition then                 
                -- not sure how to deal with "if not not (true | false) then" yet
                if 
                    condition == upvalue.data or 
                    condition.source == upvalue.data or 
                    condition.source_left == upvalue.data or 
                    condition.source_right == upvalue.data or
                    condition.type_checked == upvalue.data 
                then
                    local copy = self:CopyUpvalue(upvalue)

                    if scope.test_condition_inverted then
                        copy.data = (condition.falsy_set or copy.data:GetFalsy()):Copy()
                    else
                        copy.data = (condition.truthy_set or copy.data:GetTruthy()):Copy()
                    end

                    copy.original = upvalue.data
                    return copy
                end
            end
        end

        return upvalue
    end

    function META:OnMutateUpvalue(upvalue, key, val, env)
        if self.scope.uncertain then
            --[[
                local x = false -- << shadowed upvalue

                if maybe then
                    -- uncertain scope

                    -- instead of mutating the upvalue, create a new one
                    x = true

                    -- then turn the shadowed upvalue into a set of true | false
                else
                    !! but x should not be true | false here !!
                end

            ]]

            -- new upvalue
            self:CreateLocalValue(key, val, env)

            -- mutate shadowed upvalue
            if self.scope.test_condition_inverted and upvalue.data_outside_of_if_blocks then
                -- if we're in an uncertain else block, 
                -- we remove the original shadowed upvalue from the set
                -- because it has to be either true or false

                upvalue.data_outside_of_if_blocks:AddType(val)
                upvalue.data_outside_of_if_blocks:RemoveType(upvalue.data)
            else
                upvalue.data_outside_of_if_blocks = types.Set({upvalue.data, val})
            end

            return true
        end
    end
end

function META:CheckTypeAgainstContract(val, contract)
    if contract.Type == "list" and val.Type == "table" then
        val = types.List(val:GetEnvironmentValues())
    end
    
    local skip_uniqueness = contract:IsUnique() and not val:IsUnique()

    if skip_uniqueness then
        contract:DisableUniqueness()
    end

    local ok, reason = val:SubsetOf(contract)

    if skip_uniqueness then
        contract:EnableUniqueness()
        val.unique_id = contract.unique_id
    end

    if not ok then
        return ok, reason
    end

    if contract.Type == "table" then
        return val:ContainsAllKeysIn(contract)
    end

    return true
end

do -- statements
    function META:AnalyzeRootStatement(statement, ...)
        local argument_tuple = ... and types.Tuple({...}) or types.Tuple({...}):SetElementType(types.Any()):Max(math.huge)
        self:PushScope(statement)
        self:PushEnvironment(statement, nil, "runtime")
        self:PushEnvironment(statement, nil, "typesystem")

        self:CreateLocalValue("...", argument_tuple, "runtime")
        self:PushReturn()
        local analyzed_return = self:AnalyzeStatementsAndCollectReturnTypes(statement)

        self:PopEnvironment("runtime")
        self:PopEnvironment("typesystem")
        self:PopScope()
        return analyzed_return
    end

    function META:AnalyzeAssignmentStatement(statement)
        local env = self.PreferTypesystem and "typesystem" or statement.environment or "runtime"

        local left = {}
        local right = {}

        for i, exp_key in ipairs(statement.left) do
            if exp_key.kind == "value" then
                left[i] = exp_key
                if exp_key.kind == "value" then
                    exp_key.is_upvalue = self:FindLocalValue(exp_key, env) ~= nil
                end
            elseif exp_key.kind == "postfix_expression_index" then
                left[i] = self:AnalyzeExpression(exp_key.expression, env)
            elseif exp_key.kind == "binary_operator" then
                left[i] = self:AnalyzeExpression(exp_key.right, env)
            else
                self:FatalError("unhandled expression " .. tostring(exp_key))
            end
        end

        if statement.right then
            for right_pos, exp_val in ipairs(statement.right) do
                
                self.left_assigned = left[right_pos]

                for tuple_index, obj in ipairs({self:AnalyzeExpression(exp_val, env)}) do
                    local index = right_pos + tuple_index - 1

                    if obj.Type == "tuple" then
                        for i = 1, #statement.left do
                            right[index + i - 1] = obj:Get(i)
                        end
                    else
                        right[index] = obj
                    end

                    if exp_val.explicit_type then
                        obj:Seal()
                    end
                end
            end

            -- complicated
            local last = statement.right[#statement.right]
            
            if last.kind == "value" and last.value.value ~= "..." then
                for _ = 1, #right - #statement.right do
                    table.remove(right, #right)
                end
            end
        end

        for i, exp_key in ipairs(statement.left) do
            local val = right[i] or self:NewType(exp_key, "nil")

            if exp_key.explicit_type then
                local contract = self:AnalyzeExpression(exp_key.explicit_type, "typesystem")
        
                if right[i] then
                    val:CopyLiteralness(contract)
                    self:Assert(statement or val.node or exp_key.explicit_type, self:CheckTypeAgainstContract(val, contract))
                end

                val.contract = contract

                if not right[i] then
                    val = contract:Copy()
                    val.contract = contract
                end
            end

            exp_key.inferred_type = val

            if statement.kind == "local_assignment" then
                self:CreateLocalValue(exp_key, val, env)
            elseif statement.kind == "assignment" then
                local key = left[i]
                
                if exp_key.kind == "value" then

                    do -- check for any previous upvalues
                        local upvalue = self:GetEnvironmentValue(key, env)
                        local upvalues_contract = upvalue and upvalue.contract

                        if not upvalues_contract and env == "runtime" then
                            upvalue = self:GetEnvironmentValue(key, "typesystem")
                            if upvalue then
                                upvalues_contract = upvalue
                            end
                        end
                        
                        if upvalues_contract then
                            val:CopyLiteralness(upvalues_contract)
                            self:Assert(statement or val.node or exp_key.explicit_type, self:CheckTypeAgainstContract(val, upvalues_contract))
                            val.contract = upvalues_contract
                        end
                    end
                    
                    self:SetEnvironmentValue(key, val, env)
                else
                    local obj = self:AnalyzeExpression(exp_key.left, env)
                    self:Assert(exp_key, self:SetOperator(obj, key, val, exp_key))
                    self:FireEvent("newindex", obj, key, val, env)
                end
            end
        end
    end

    function META:AnalyzeDestructureStatement(statement)
        local env = statement.environment or "runtime"
        local obj = self:AnalyzeExpression(statement.right, env)

        if obj.Type ~= "table" then
            self:Error(statement.right, "expected a table on the right hand side, got " .. tostring(obj))
        end

        if statement.default then
            if statement.kind == "local_destructure_assignment" then
                self:CreateLocalValue(statement.default, obj, env)
            elseif statement.kind == "destructure_assignment" then
                self:SetEnvironmentValue(statement.default, obj, env)
            end
        end

        for _, node in ipairs(statement.left) do
            local obj = node.value and obj:Get(node.value.value, env) or self:NewType(node, "nil")

            if statement.kind == "local_destructure_assignment" then
                self:CreateLocalValue(node, obj, env)
            elseif statement.kind == "destructure_assignment" then
                self:SetEnvironmentValue(node, obj, env)
            end
        end
    end

    function META:AnalyzeFunctionStatement(statement)
        local existing_type = self:GetEnvironmentValue(statement.expression, "typesystem")

        if existing_type then
            self:SetEnvironmentValue(statement.expression, existing_type, "runtime")
        else
            self:SetEnvironmentValue(statement.expression, self:AnalyzeFunctionExpression(statement, "runtime"), "runtime")
        end
    end

    function META:AnalyzeTypeFunctionStatement(statement)
        self:SetEnvironmentValue(
            statement.expression,
            self:AnalyzeFunctionExpression(statement:ToExpression("type_function"),
            "typesystem"
        ), "typesystem")
    end

    function META:AnalyzeTypeCodeStatement(statement)
        local code = statement.lua_code.value.value:sub(3)
        self:CallLuaTypeFunction(statement.lua_code, self:CompileLuaTypeCode(code, statement.lua_code))
    end

    function META:AnalyzeIfStatement(statement)
        local prev_expression
        for i, statements in ipairs(statement.statements) do
            if statement.expressions[i] then
                local obj = self:AnalyzeExpression(statement.expressions[i], "runtime")

                prev_expression = obj

                if obj:IsTruthy() then
                    self:PushScope(statement, statement.tokens["if/else/elseif"][i], {                            
                        if_position = i, 
                        condition = obj
                    })
                        
                    self:AnalyzeStatements(statements)

                    self:PopScope({
                        if_position = i, 
                        condition = obj
                    })

                    if not obj:IsFalsy() then
                        break
                    end
                end
            else
                if prev_expression:IsFalsy() then
                    self:PushScope(statement, statement.tokens["if/else/elseif"][i], {
                        if_position = i, 
                        is_else = true,
                        condition = prev_expression
                    })

                    self:AnalyzeStatements(statements)

                    self:PopScope({
                        if_position = i,
                        is_else = true,
                        condition = prev_expression
                    })
                end
            end
        end
        self:OnLeaveIfStatement()
    end

    function META:AnalyzeWhileStatement(statement)
        local obj = self:AnalyzeExpression(statement.expression)
        if obj:IsTruthy() then
            self:PushScope(statement, nil, {
                condition = obj
            })
            self:AnalyzeStatements(statement.statements)
            self:PopScope({
                condition = obj
            })
        end
    end

    function META:AnalyzeDoStatement(statement)
        self:PushScope(statement)
        self:AnalyzeStatements(statement.statements)
        self:PopScope()
    end

    function META:AnalyzeRepeatStatement(statement)
        self:PushScope(statement)
        self:AnalyzeStatements(statement.statements)
        if self:AnalyzeExpression(statement.expression):IsTruthy() then
            self:FireEvent("break")
        end
        self:PopScope()
    end

    function META:AnalyzeReturnStatement(statement)
        local ret = self:AnalyzeExpressions(statement.expressions)
        
        -- do return end > do return nil end
        if not ret[1] then
            ret[1] = self:NewType(statement, "nil")
        end
        self:CollectReturnExpressions(ret)
        self.returned_from_certain_scope = not self:GetScope().uncertain
        self.returned_from_block = true
        self:FireEvent("return", ret)
    end

    function META:AnalyzeGenericForStatement(statement)
        local args = self:AnalyzeExpressions(statement.expressions)
        local obj = args[1]

        if obj then
            table.remove(args, 1)

            local returned_key = nil
            
            local one_loop = args[1] and args[1].Type == "any"

            for i = 1, 1000 do
                local values = self:Assert(statement.expressions[1], self:Call(obj, types.Tuple(args), statement.expressions[1]))

                if not values:Get(1) or values:Get(1).Type == "symbol" and values:Get(1).data == nil then
                    break
                end

                if i == 1 then
                    returned_key = values:Get(1)
                    if not returned_key:IsLiteral() then
                        returned_key = types.Set({types.Symbol(nil), returned_key})
                    end
                    self:PushScope(statement, nil, {condition = returned_key})
                end

                for i,v in ipairs(statement.identifiers) do
                    self:CreateLocalValue(v, values:Get(i), "runtime")
                end

                self:AnalyzeStatements(statement.statements)

                if i == 1000 then
                    self:Error(statement, "too many iterations")
                end

                table.insert(values.data, 1, args[1])

                args = values:GetData()

                if one_loop then
                    break
                end
            end

            if returned_key then
                self:PopScope({condition = returned_key})
            end
        end

    end

    function META:AnalyzeNumericForStatement(statement)
        local init = self:AnalyzeExpression(statement.expressions[1])
        local max = self:AnalyzeExpression(statement.expressions[2])
        local step = statement.expressions[3] and self:AnalyzeExpression(statement.expressions[3]) or nil

        local literal_init = init:IsLiteral() and init:GetData() or nil
        local literal_max = max:IsLiteral() and max:GetData() or nil
        local literal_step = not step and 1 or step:IsLiteral() and step:GetData() or nil

        local condition = types.Set()

        if literal_init and literal_max then
            -- also check step
            condition:AddType(types.Symbol(init:GetData() <= max:GetData()))
        else
            condition:AddType(types.Symbol(true))
            condition:AddType(types.Symbol(false))
        end
        
        self:PushScope(statement, nil, {init = init, max = max, condition = condition})

        if literal_init and literal_max and literal_step and literal_max < 1000 then
            local uncertain_break = nil
            for i = literal_init, literal_max, literal_step do
                local i = self:NewType(statement.expressions[1], "number", i):MakeLiteral(true)
                local brk = false
                
                if uncertain_break then
                    i:MakeLiteral(false)
                    brk = true
                end

                self:CreateLocalValue(statement.identifiers[1], i, "runtime")
                self:AnalyzeStatements(statement.statements)
                if self.break_out then
                    if self.break_out.scope.uncertain then
                        uncertain_break = i
                        self.break_out = nil
                    else
                        self.break_out = nil
                        brk = true
                    end
                end

                if brk then
                    break
                end
            end
        else
            if init.Type == "number" and (max.Type == "number" or (max.Type == "set" and max:IsType("number"))) then
                init = init:Max(max)
            end

            if max.Type == "any" then
                init:MakeLiteral(false)
            end

            local range = self:Assert(statement.expressions[1], init)

            self:CreateLocalValue(statement.identifiers[1], range, "runtime")
            self:AnalyzeStatements(statement.statements)
        end
        self:PopScope({init = init, max = max, condition = condition})
    end

    function META:AnalyzeLocalFunctionStatement(statement)
        self:CreateLocalValue(statement.tokens["identifier"], self:AnalyzeFunctionExpression(statement, "runtime"), "runtime")
    end

    function META:AnalyzeLocalTypeFunctionStatement(statement)
        if statement.kind == "local_type_function" then
            self:CreateLocalValue(statement.identifier, self:AnalyzeFunctionExpression(statement:ToExpression("type_function"), "typesystem"), "typesystem")
        else
            self:CreateLocalValue(statement.identifier, self:AnalyzeFunctionExpression(statement, "typesystem"), "typesystem")
        end
    end

    function META:AnalyzeBreakStatement(statement)
        self.break_out = {
            scope = self:GetScope()
        }
        self:FireEvent("break")
    end

    function META:AnalyzeCallExpression(statement)
        local foo = self:AnalyzeExpression(statement.value)
        self:FireEvent("call", statement.value, {foo})
    end

    function META:AnalyzeStatement(statement)
        self.current_statement = statement

        if statement.kind == "assignment" or statement.kind == "local_assignment" then
           self:AnalyzeAssignmentStatement(statement) 
        elseif statement.kind == "destructure_assignment" or statement.kind == "local_destructure_assignment" then
            self:AnalyzeDestructureStatement(statement)
        elseif statement.kind == "function" then
            self:AnalyzeFunctionStatement(statement)
        elseif statement.kind == "type_function" then
            self:AnalyzeTypeFunctionStatement(statement)
        elseif statement.kind == "local_function" then
            self:AnalyzeLocalFunctionStatement(statement)
        elseif statement.kind == "local_generics_type_function" or statement.kind == "local_type_function" then
            self:AnalyzeLocalTypeFunctionStatement(statement)
        elseif statement.kind == "if" then
            self:AnalyzeIfStatement(statement)
        elseif statement.kind == "while" then
            self:AnalyzeWhileStatement(statement)
        elseif statement.kind == "do" then
            self:AnalyzeDoStatement(statement)
        elseif statement.kind == "repeat" then
            self:AnalyzeRepeatStatement(statement)
        elseif statement.kind == "return" then
            self:AnalyzeReturnStatement(statement)
        elseif statement.kind == "break" then
            self:AnalyzeBreakStatement(statement)
        elseif statement.kind == "call_expression" then
            self:AnalyzeCallExpression(statement)
        elseif statement.kind == "generic_for" then
            self:AnalyzeGenericForStatement(statement)
        elseif statement.kind == "numeric_for" then
            self:AnalyzeNumericForStatement(statement)
        elseif statement.kind == "type_code" then
            self:AnalyzeTypeCodeStatement(statement)
        elseif
            statement.kind ~= "end_of_file" and
            statement.kind ~= "semicolon" and
            statement.kind ~= "shebang" and
            statement.kind ~= "goto_label" and
            statement.kind ~= "goto"
        then
            error("unhandled statement " .. tostring(statement))
        end
    end
end

do -- expressions
    do -- binary operator
        local operators = {
            ["+"] = function(l,r) return l+r end,
            ["-"] = function(l,r) return l-r end,
            ["*"] = function(l,r) return l*r end,
            ["/"] = function(l,r) return l/r end,
            ["/idiv/"] = function(l,r) return (math.modf(l/r)) end,
            ["%"] = function(l,r) return l%r end,
            ["^"] = function(l,r) return l^r end,
            [".."] = function(l,r) return l..r end,

            ["&"] = function(l, r) return bit.band(l,r) end,
            ["|"] = function(l, r) return bit.bor(l,r) end,
            ["~"] = function(l,r) return bit.bxor(l,r) end,
            ["<<"] = function(l, r) return bit.lshift(l,r) end,
            [">>"] = function(l, r) return bit.rshift(l,r) end,

            ["=="] = function(l,r) return l==r end,
            ["<"] = function(l,r) return l<r end,
            ["<="] = function(l,r) return l<=r end,
        }

        local function metatable_function(self, meta_method, l,r, swap)
            if swap then
                l,r = r,l
            end

            if r.meta or l.meta then
                local func = (l.meta and l.meta:Get(meta_method)) or (r.meta and r.meta:Get(meta_method))

                if func then
                    if func.Type == "function" then
                        return self:Assert(self.current_expression, self:Call(func, types.Tuple({l, r}))):Get(1)
                    else
                        return func
                    end
                end
            end
        end

        local function arithmetic(node, l,r, type, operator)
            assert(operators[operator], "cannot map operator " .. tostring(operator))

            if type and l.Type == type and r.Type == type then
                if l:IsLiteral() and r:IsLiteral() then
                    local obj = types.Number(operators[operator](l.data, r.data)):MakeLiteral(true)

                    if r.max then
                        obj.max = arithmetic(node, l, r.max, type, operator)
                    end

                    if l.max then
                        obj.max = arithmetic(node, l.max, r, type, operator)
                    end

                    return obj:SetSource(node, obj, l,r)
                end

                local obj = types.Number():Copy()
                return obj:SetSource(node, obj, l,r)
            end

            return types.errors.other("no operator for " .. tostring(l) .. " " .. operator .. " " .. tostring(r) .. " in runtime")
        end

        function META:BinaryOperator(node, l, r, env)
            local op = node.value.value

            -- adding two tuples at runtime in lua will practically do this
            if l.Type == "tuple" then l = l:Get(1) end
            if r.Type == "tuple" then r = r:Get(1) end

            -- normalize l and r to be both sets to reduce complexity
            if l.Type ~= "set" and r.Type == "set" then l = types.Set({l}) end
            if l.Type == "set" and r.Type ~= "set" then r = types.Set({r}) end

            if l.Type == "set" and r.Type == "set" then
                local new_set = types.Set()
                local truthy_set = types.Set()
                local falsy_set = types.Set()
                local condition = l
                
                for _, l in ipairs(l:GetTypes()) do
                    for _, r in ipairs(r:GetTypes()) do
                        local res, err = self:BinaryOperator(node, l, r, env)

                        if not res then
                            self:Report(node, err)
                            self:CloneCurrentScope()
                            self:GetScope().test_condition = condition
                        else
                            if res:IsTruthy() then
                                if self.type_checked then                                
                                    for _, t in ipairs(self.type_checked:GetTypes()) do
                                        if t:GetLuaType() == l:GetData() then
                                            truthy_set:AddType(t)
                                        end
                                    end                                
                                    
                                else
                                    truthy_set:AddType(l)
                                end
                            end
        
                            if res:IsFalsy() then
                                if self.type_checked then                                
                                    for _, t in ipairs(self.type_checked:GetTypes()) do
                                        if t:GetLuaType() == l:GetData() then
                                            falsy_set:AddType(t)
                                        end
                                    end                                
                                    
                                else
                                    falsy_set:AddType(l)
                                end
                            end

                            new_set:AddType(res)
                        end
                    end
                end
                
                if self.type_checked then
                    new_set.type_checked = self.type_checked
                    self.type_checked = nil
                end

                new_set.truthy_set = truthy_set
                new_set.falsy_set = falsy_set

                return new_set:SetSource(node, new_set, l,r)
            end

            if env == "typesystem" then
                if op == "|" then
                    return types.Set({l, r})
                elseif op == "&" then
                    if l.Type == "table" and r.Type == "table" then
                        return l:Extend(r)
                    end
                elseif op == "extends" then
                    return l:Extend(r)
                elseif op == ".." then
                    return l:Copy():Max(r)
                elseif op == ">" then
                    return types.Symbol((r:SubsetOf(l)))
                elseif op == "<" then
                    return types.Symbol((l:SubsetOf(r)))
                elseif op == "+" then
                    if l.Type == "table" and r.Type == "table" then
                        return l:Union(r)
                    end
                end
            end

            if op == "." or op == ":" then
                return self:GetOperator(l, r, node)
            end

            if l.Type == "any" or r.Type == "any" then
                return types.Any()
            end

            if op == "+" then local res = metatable_function(self, "__add", l, r) if res then return res end
            elseif op == "-" then local res = metatable_function(self, "__sub", l, r) if res then return res end
            elseif op == "*" then local res = metatable_function(self, "__mul", l, r) if res then return res end
            elseif op == "/" then local res = metatable_function(self, "__div", l, r) if res then return res end
            elseif op == "/idiv/" then local res = metatable_function(self, "__idiv", l, r) if res then return res end
            elseif op == "%" then local res = metatable_function(self, "__mod", l, r) if res then return res end
            elseif op == "^" then local res = metatable_function(self, "__pow", l, r) if res then return res end
            elseif op == "&" then local res = metatable_function(self, "__band", l, r) if res then return res end
            elseif op == "|" then local res = metatable_function(self, "__bor", l, r) if res then return res end
            elseif op == "~" then local res = metatable_function(self, "__bxor", l, r) if res then return res end
            elseif op == "<<" then local res = metatable_function(self, "__lshift", l, r) if res then return res end
            elseif op == ">>" then local res = metatable_function(self, "__rshift", l, r) if res then return res end end

            if l.Type == "number" and r.Type == "number" then
                if op == "~=" or op == "!=" then
                    if l.max and l.max.data then
                        return (not (r.data >= l.data and r.data <= l.max.data)) and types.True or types.Set({types.True, types.False})
                    end

                    if r.max and r.max.data then
                        return (not (l.data >= r.data and l.data <= r.max.data)) and types.True or types.Set({types.True, types.False})
                    end
                elseif op == "==" then
                    if l.max and l.max.data then
                        return r.data >= l.data and r.data <= l.max.data and types.Set({types.True, types.False}) or types.False
                    end

                    if r.max and r.max.data then
                        return l.data >= r.data and l.data <= r.max.data and types.Set({types.True, types.False}) or types.False
                    end
                end
            end

            if op == "==" then
                local res = metatable_function(self, "__eq", l, r)
                if res then
                    return res
                end

                if l:IsLiteral() and r:IsLiteral() and l.Type == r.Type then

                    if l.Type == "table" then
                        if env == "runtime" then
                            if l.reference_id and r.reference_id then
                                return l.reference_id == r.reference_id and types.True or types.False
                            end
                        end

                        if env == "typesystem" then
                            return l:SubsetOf(r) and r:SubsetOf(l) and types.True or types.False
                        end 

                        return types.Boolean
                    end


                    return l.data == r.data and types.True or types.False
                end

                if l.Type == "table" and r.Type == "table" then
                    if env == "typesystem" then
                        return l:SubsetOf(r) and r:SubsetOf(l) and types.True or types.False
                    end
                end

                if l.Type == "symbol" and r.Type == "symbol" and l:GetData() == nil and r:GetData() == nil then
                    return types.True
                end

                if l.Type ~= r.Type then
                    return types.False
                end

                if l == r then
                    return types.True
                end

                return types.Boolean
            elseif op == "~=" then
                local res = metatable_function(self, "__eq", l, r)
                if res then
                    if res:IsLiteral() then
                        res.data = not res.data
                    end
                    return res
                end
                if l:IsLiteral() and r:IsLiteral() then
                    return l.data ~= r.data and types.True or types.False
                end

                if l == types.Nil and r == types.Nil then
                    return types.True
                end

                if l.Type ~= r.Type then
                    return types.True
                end

                if l == r then
                    return types.False
                end

                return types.Boolean
            elseif op == "<" then
                local res = metatable_function(self, "__lt", l, r)
                if res then
                    return res
                end
                if l:IsLiteral() and r:IsLiteral() and ((l.Type == "string" and r.Type == "string") or (l.Type == "number" and r.Type == "number")) then
                    return types.Symbol(l.data < r.data)
                end

                return types.Boolean
            elseif op == "<=" then
                local res = metatable_function(self, "__le", l, r)
                if res then
                    return res
                end
                if l:IsLiteral() and r:IsLiteral() and ((l.Type == "string" and r.Type == "string") or (l.Type == "number" and r.Type == "number")) then
                    return types.Symbol(l.data <= r.data)
                end

                return types.Boolean
            elseif op == ">" then
                local res = metatable_function(self, "__lt", l, r)
                if res then
                    return res
                end
                if l:IsLiteral() and r:IsLiteral() and ((l.Type == "string" and r.Type == "string") or (l.Type == "number" and r.Type == "number")) then
                    return types.Symbol(l.data > r.data)
                end

                return types.Boolean
            elseif op == ">=" then
                local res = metatable_function(self, "__le", l, r)
                if res then
                    return res
                end
                if l:IsLiteral() and r:IsLiteral() and ((l.Type == "string" and r.Type == "string") or (l.Type == "number" and r.Type == "number")) then
                    return types.Symbol(l.data >= r.data)
                end

                return types.Boolean
            elseif op == "or" or op == "||" then
                if l:IsUncertain() or r:IsUncertain() then
                    local set = types.Set({l,r})
                    return set:SetSource(node, set, l,r)
                end

                -- when true, or returns its first argument
                if l:IsTruthy() then
                    return l:Copy():SetSource(node, l, l,r)
                end

                if r:IsTruthy() then
                    return r:Copy():SetSource(node, r, l,r)
                end

                return r:Copy():SetSource(node, r)
            elseif op == "and" or op == "&&" then
                if l:IsTruthy() and r:IsFalsy() then
                    if l:IsFalsy() or r:IsTruthy() then
                        local set = types.Set({l,r})
                        return set:SetSource(node, set, l,r)
                    end

                    return r:Copy():SetSource(node, r, l,r)
                end

                if l:IsFalsy() and r:IsTruthy() then
                    if l:IsTruthy() or r:IsFalsy() then
                        local set = types.Set({l,r})
                        return set:SetSource(node, set, l,r)
                    end

                    return l:Copy():SetSource(node, l, l,r)
                end

                if l:IsTruthy() and r:IsTruthy() then
                    if l:IsFalsy() and r:IsFalsy() then
                        local set = types.Set({l,r})
                        return set:SetSource(node, set, l,r)
                    end

                    return r:Copy():SetSource(node, r, l,r)
                else
                    if l:IsTruthy() and r:IsTruthy() then
                        local set = types.Set({l,r})
                        return set:SetSource(node, set, l,r)
                    end

                    return l:Copy():SetSource(node, l, l,r)
                end
            end

            if op == ".." then
                if
                    (l.Type == "string" and r.Type == "string") or
                    (l.Type == "number" and r.Type == "string") or
                    (l.Type == "number" and r.Type == "number") or
                    (l.Type == "string" and r.Type == "number")
                then
                    if l:IsLiteral() and r:IsLiteral() then
                        return self:NewType(node, "string", l.data .. r.data, true)
                    end

                    return self:NewType(node, "string")
                end

                return types.errors.other("no operator for " .. tostring(l) .. " " .. ".." .. " " .. tostring(r))
            end

            if op == "+" then return arithmetic(node, l,r, "number", op)
            elseif op == "-" then return arithmetic(node, l,r, "number", op)
            elseif op == "*" then return arithmetic(node, l,r, "number", op)
            elseif op == "/" then return arithmetic(node, l,r, "number", op)
            elseif op == "/idiv/" then return arithmetic(node, l,r, "number", op)
            elseif op == "%" then return arithmetic(node, l,r, "number", op)
            elseif op == "^" then return arithmetic(node, l,r, "number", op)

            elseif op == "&" then return arithmetic(node, l,r, "number", op)
            elseif op == "|" then return arithmetic(node, l,r, "number", op)
            elseif op == "~" then return arithmetic(node, l,r, "number", op)
            elseif op == "<<" then return arithmetic(node, l,r, "number", op)
            elseif op == ">>" then return arithmetic(node, l,r, "number", op) end

            return types.errors.other("no operator for " .. tostring(l) .. " " .. op .. " " .. tostring(r))
        end

        function META:AnalyzeBinaryOperatorExpression(node, env)
            local left
            local right

            if node.value.value == "and" then
                left = self:AnalyzeExpression(node.left, env)
                if left:IsFalsy() and left:IsTruthy() then
                    -- if it's uncertain, remove uncertainty while analysing
                    if left.Type == "set" then
                        left:DisableFalsy()
                    end
                    right = self:AnalyzeExpression(node.right, env)
                    if left.Type == "set" then
                        left:EnableFalsy()
                    end
                elseif left:IsFalsy() and not left:IsTruthy() then
                    -- if it's really false do nothing
                    right = self:NewType(node.right, "nil")
                else
                    right = self:AnalyzeExpression(node.right, env)    
                end
            elseif node.value.value == "or" then
                left = self:AnalyzeExpression(node.left, env)

                if left:IsTruthy() and not left:IsFalsy() then
                    right = self:NewType(node.right, "nil")
                elseif left:IsFalsy() and not left:IsTruthy() then
                    right = self:AnalyzeExpression(node.right, env)
                else
                    right = self:AnalyzeExpression(node.right, env)
                end
            else
                left = self:AnalyzeExpression(node.left, env)
                right = self:AnalyzeExpression(node.right, env)    
            end

            if node.and_expr then
                if node.and_expr.and_res == left then
                    if left.Type == "set" then
                        left = left:Copy()
                        left:DisableFalsy()
                    end
                end
            end

            assert(left)
            assert(right)

            -- TODO: more elegant way of dealing with self?
            if node.value.value == ":" then
                self.self_arg_stack = self.self_arg_stack or {}
                table.insert(self.self_arg_stack, left)
            end

            return self:Assert(node, self:BinaryOperator(node, left, right, env))
        end
    end

    do -- prefix operator
        local operators = {
            ["-"] = function(l) return -l end,
            ["~"] = function(l) return bit.bnot(l) end,
            ["#"] = function(l) return #l end,
        }

        local function metatable_function(self, meta_method, l)
            if l.meta then
                local func = l.meta:Get(meta_method)

                if func then
                    return self:Call(func, types.Tuple({l})):Get(1)
                end
            end
        end

        local function arithmetic(l, type, operator)
            assert(operators[operator], "cannot map operator " .. tostring(operator))
            if l.Type == type then
                if l:IsLiteral() then
                    local obj = types.Number(operators[operator](l.data)):MakeLiteral(true)

                    if l.max then
                        obj.max = arithmetic(l.max, type, operator)
                    end

                    return obj
                end

                return types.Number()
            end

            return types.errors.other("no operator for " .. operator .. tostring(l) .. " in runtime")
        end

        function META:PrefixOperator(node, l, env)
            local op = node.value.value

            if l.Type == "tuple" then l = l:Get(1) end

            if l.Type == "set" then
                local new_set = types.Set()
                local truthy_set = types.Set()
                local falsy_set = types.Set()

                for _, l in ipairs(l:GetTypes()) do
                    local res = self:Assert(node, self:PrefixOperator(node, l, env))
                    new_set:AddType(res)


                    if res:IsTruthy() then
                        truthy_set:AddType(l)
                    end

                    if res:IsFalsy() then
                        falsy_set:AddType(l)
                    end
                end

                new_set.truthy_set = truthy_set
                new_set.falsy_set = falsy_set

                return new_set:SetSource(node, l)
            end

            if l.Type == "any" then
                return types.Any()
            end

            if env == "typesystem" then
                if op == "typeof" then
                    local obj = self:AnalyzeExpression(node.right, "runtime")

                    if not obj then
                        return types.errors.other("cannot find '" .. node.right:Render() .. "' in the current typesystem scope")
                    end
                    return obj.contract or obj
                elseif op == "unique" then
                    local obj = self:AnalyzeExpression(node.right, "typesystem")
                    obj:MakeUnique(true)
                    return obj
                elseif op == "out" then
                    local obj = self:AnalyzeExpression(node.right, "typesystem")
                    obj.out = true
                    return obj
                elseif op == "$" then
                    local obj = self:AnalyzeExpression(node.right, "typesystem")
                    if obj.Type ~= "string" then
                        return types.errors.other("must evaluate to a string")
                    end
                    if not obj:IsLiteral() then
                        return types.errors.other("must be a literal")
                    end

                    obj.pattern_contract = obj:GetData()

                    return obj
                end
            end

            if op == "-" then local res = metatable_function(self, "__unm", l) if res then return res end
            elseif op == "~" then local res = metatable_function(self, "__bxor", l) if res then return res end
            elseif op == "#" then local res = metatable_function(self, "__len", l) if res then return res end end

            if op == "not" or op == "!" then
                if l:IsTruthy() and l:IsFalsy() then
                    return self:NewType(node, "boolean", nil, false, l):SetSource(node, l)
                end

                if l:IsTruthy() then
                    return self:NewType(node, "boolean", false, true, l):SetSource(node, l)
                end

                if l:IsFalsy() then
                    return self:NewType(node, "boolean", true, true, l):SetSource(node, l)
                end
            end


            if op == "-" then return arithmetic(l, "number", op)
            elseif op == "~" then return arithmetic(l, "number", op)
            elseif op == "#" then
                if l.Type == "table" then
                    return types.Number(l:GetLength()):MakeLiteral(l:IsLiteral())
                elseif l.Type == "string" then
                    return types.Number(l:GetData() and #l:GetData() or nil):MakeLiteral(l:IsLiteral())
                end
            end

            error("unhandled prefix operator in " .. env .. ": " .. op .. tostring(l))
        end

        function META:AnalyzePrefixOperatorExpression(node, env)
            return self:Assert(node, self:PrefixOperator(node, self:AnalyzeExpression(node.right, env), env))
        end
    end

    do -- postfix operator
        function META:PostfixOperator(node, r, env)
            local op = node.value.value
    
            if op == "++" then
                return self:BinaryOperator({value = {value = "+"}}, r, r, env)
            end
        end

        function META:AnalyzePostfixOperatorExpression(node, env)
            return self:Assert(
                node, 
                self:PostfixOperator(
                    node, 
                    self:AnalyzeExpression(node.left, env), 
                    env
                )
            )
        end
    end
    
    function META:AnalyzePostfixCallExpression(node, env)
        local obj = self:AnalyzeExpression(node.left, env)
        local arguments = self:AnalyzeExpressions(node.expressions, node.type_call and "typesystem" or env)

        if self.self_arg_stack and node.left.kind == "binary_operator" and node.left.value.value == ":" then
            table.insert(arguments, 1, table.remove(self.self_arg_stack))
        end

        self.PreferTypesystem = node.type_call
        local obj = self:Assert(node, self:Call(obj, types.Tuple(arguments), node))
        self.PreferTypesystem = nil
        
        if obj:IsEmpty() then
            obj:Set(1, self:NewType(node, "nil"))
        end

        -- TODO: hacky workaround for trimming the returned tuple
        -- local a,b,c = (foo())
        -- b and c should be nil, a should be something
        if not obj:IsEmpty() and node.tokens["("] and node.tokens[")"] then
            obj = obj:Get(1)
        end

        if obj.Type == "tuple" then
            return obj:Unpack()
        end
        
        return obj
    end

    function META:AnalyzePostfixExpressionIndexExpression(node, env)
        return self:Assert(
            node, 
            self:GetOperator(
                self:AnalyzeExpression(node.left, env), 
                self:AnalyzeExpression(node.expression, env), 
                node
            )
        )
    end

    function META:AnalyzeVarargTupleExpression(node, env)
        local obj = self:NewType(node, "...")
        obj:SetElementType(self:GetEnvironmentValue(node.value, "typesystem"))
        return obj
    end

    local syntax = require("oh.lua.syntax")

    function META:LookupValue(node, env)
        local obj

        if env == "typesystem" then
            obj = 
                self:GetEnvironmentValue(node, env) or
                self:GetEnvironmentValue(node, "runtime")
            
            if not obj then
                self:Error(node, "cannot find value " .. node.value.value)
            end
        else
            obj = 
                self:GetEnvironmentValue(node, env) or 
                self:GetEnvironmentValue(node, "typesystem") or 
                self:GuessTypeFromIdentifier(node, env)
        end

        node.inferred_type = node.inferred_type or obj
        node.is_upvalue = self:FindLocalValue(node, env) ~= nil
        
        if obj.Type == "tuple" then
            return obj:Unpack()
        end
        
        return obj
    end

    function META:AnalyzeSingleValueExpression(node, env)
        local value = node.value.value
        local type = syntax.GetTokenType(node.value)

        -- this means it's the first part of something, either >true<, >foo<.bar, >foo<()
        local standalone_letter = type == "letter" and node.standalone_letter

        if env == "typesystem" and standalone_letter and not node.force_upvalue then
            if value == "any" then
                return self:NewType(node, "any")
            elseif value == "never" then
                return self:NewType(node, "never")
            elseif value == "error" then
                return self:NewType(node, "error")
            elseif (value == "self" and self.current_table) or (self.current_table and self.left_assigned and self.left_assigned.value.value == value and not types.IsPrimitiveType(value)) then
                return self.current_table
            elseif value == "inf" then
                return self:NewType(node, "number", math.huge, true)
            elseif value == "nan" then
                return self:NewType(node, "number", 0/0, true)
            elseif types.IsPrimitiveType(value) then
                return self:NewType(node, value)
            end
        end

        if standalone_letter or value == "..." or node.force_upvalue then
            return self:LookupValue(node, env)
        end

        if type == "keyword" then
            if value == "nil" then
                return self:NewType(node, "nil", nil, env == "typesystem")
            elseif value == "true" then
                return self:NewType(node, "boolean", true, true)
            elseif value == "false" then
                return self:NewType(node, "boolean", false, true)
            end
        end

        if type == "number" then
            return self:NewType(node, "number", self:StringToNumber(value), true)
        elseif type == "string" then
            if value:sub(1, 1) == "[" then
                local start = value:match("(%[[%=]*%[)")
                return self:NewType(node, "string", value:sub(#start+1, -#start-1), true)
            else
                return self:NewType(node, "string", value:sub(2, -2), true)
            end
        elseif type == "letter" then
            return self:NewType(node, "string", value, true)
        end

        self:FatalError("unhandled value type " .. type .. " " .. node:Render())
    end

    function META:AnalyzeFunctionExpression(node, env)
        local explicit_arguments = false
        local explicit_return = false

        local args = {}

        if node.kind == "function" or node.kind == "local_function" then
            for i, key in ipairs(node.identifiers) do
                if key.explicit_type then
                    args[i] = self:AnalyzeExpression(key.explicit_type, "typesystem")
                    explicit_arguments = true
                elseif key.value.value == "..." then
                    args[i] = self:NewType(key, "...")
                else    
                    args[i] = self:GuessTypeFromIdentifier(key)
                end
            end
        else
            for i, key in ipairs(node.identifiers) do
                if key.identifier then
                    args[i] = self:AnalyzeExpression(key, "typesystem")
                    explicit_arguments = true
                elseif key.explicit_type then
                    args[i] = self:AnalyzeExpression(key.explicit_type, "typesystem")
                    explicit_arguments = true
                elseif key.value.value == "self" then
                    args[i] = self.current_table
                elseif key.value.value == "..." then
                    args[i] = self:NewType(key, "...")
                else
                    args[i] = self:NewType(key, "any")
                end
            end    
        end
      
        if node.self_call and node.expression then
            local upvalue = self:FindLocalValue(node.expression.left, "runtime")
            if upvalue then
                if upvalue.data.contract then
                    table.insert(args, 1, upvalue.data)
                else
                    table.insert(args, 1, types.Set({types.Any(), upvalue.data}))
                end
            end
        end

        local ret = {}

		if node.return_types then
            explicit_return = true
			self:PushScope(node)
                for i, key in ipairs(node.identifiers) do
                    if key.kind == "value" then
                        self:CreateLocalValue(key, args[i], "typesystem")
                    end
				end

				for i, type_exp in ipairs(node.return_types) do
					ret[i] = self:AnalyzeExpression(type_exp, "typesystem")
				end
			self:PopScope()
        end

        args = types.Tuple(args)
        ret = types.Tuple(ret)

        local func
        if env == "typesystem" then
            if node.statements and (node.kind == "type_function" or node.kind == "local_type_function") then
                func = self:CompileLuaTypeCode("return " .. node:Render({}), node)()
            end
        end

        local obj = self:NewType(node, "function", {
            arg = args,
            ret = ret,
            lua_function = func
        })

        obj.explicit_arguments = explicit_arguments
        obj.explicit_return = explicit_return

        if env == "runtime" then
            self:CallMeLater(obj, args, node, true)
        end

        obj.analyzer_needed_for_error_handling = self

        return obj
    end

    function META:AnalyzeTableExpression(node, env)
        local tbl = self:NewType(node, "table", nil, env == "typesystem")
        if env == "runtime" then
            tbl:SetReferenceId(tostring(tbl.data))
        end
        self.current_table = tbl
        for _, node in ipairs(node.children) do
            if node.kind == "table_key_value" then
                local key = self:NewType(node.tokens["identifier"], "string", node.tokens["identifier"].value, true)
                local val = self:AnalyzeExpression(node.expression, env)
                tbl:Set(key, val)
            elseif node.kind == "table_expression_value" then
                local key = self:AnalyzeExpression(node.expressions[1], env)
                local obj = self:AnalyzeExpression(node.expressions[2], env)

                tbl:Set(key, obj)
            elseif node.kind == "table_index_value" then
                local val = {self:AnalyzeExpression(node.expression, env)}

                if val[1].Type == "tuple" then
                    tbl:Set(types.Number(node.i):Max(types.Number(val[1].max)), val[1].ElementType)
                else 
                    if node.i then
                        tbl:Insert(val[1])
                    elseif val then
                        for _, val in ipairs(val) do
                            tbl:Insert(val)
                        end
                    end
                end
            end
        end
        self.current_table = nil
        return tbl
    end

    function META:AnalyzeListExpression(node, env)
        local list = self:NewType(node, "list", nil, env == "typesystem")
        for _, node in ipairs(node.expressions) do
            local val = self:AnalyzeExpression(node, env)
            list:Insert(val)
        end

        if node.left then
            list.ElementType = self:AnalyzeExpression(node.left, env)
        end

        return list
    end

    function META:AnalyzeExpression(node, env)
        self.current_expression = node

        if not node then error("node is nil", 2) end
        if node.type ~= "expression" then error("node is not an expression", 2) end
        env = env or "runtime"
    
        if self.PreferTypesystem then
            env = "typesystem"
        end

        if node.explicit_type then
            return self:AnalyzeExpression(node.explicit_type, "typesystem")
        elseif node.kind == "value" then
            return self:AnalyzeSingleValueExpression(node, env)
        elseif node.kind == "function" or node.kind == "type_function" then
            return self:AnalyzeFunctionExpression(node, env)
        elseif node.kind == "table" or node.kind == "type_table" then
            return self:AnalyzeTableExpression(node, env)
        elseif node.kind == "type_list" then
            return self:AnalyzeListExpression(node, env)
        elseif node.kind == "binary_operator" then
            return self:AnalyzeBinaryOperatorExpression(node, env)
        elseif node.kind == "prefix_operator" then
            return self:AnalyzePrefixOperatorExpression(node, env)
        elseif node.kind == "postfix_operator" then
            return self:AnalyzePostfixOperatorExpression(node, env)
        elseif node.kind == "postfix_expression_index" then
            return self:AnalyzePostfixExpressionIndexExpression(node, env)
        elseif node.kind == "postfix_call" then
            return self:AnalyzePostfixCallExpression(node, env)
        else
            self:FatalError("unhandled expression " .. node.kind)
        end
    end
end

return function()
    local self = setmetatable({}, META)
    self.diagnostics = {}
    self.default_environment = {runtime = types.Table({}), typesystem = types.Table({})}
    self.environments = {runtime = {}, typesystem = {}}
    return self
end