
local syntax = require("oh.lua.syntax")
local types = require("oh.typesystem.types")
types.Initialize()

local META = {}

local table_insert = table.insert

do -- type operators
    function META:PostfixOperator(op, r, env)
        if r.Type == "object" then
            if op == "++" then
                if r.data and r.const then
                    return self:BinaryOperator("+", r, r, env)
                end
            end
        end
    end

    function META:PrefixOperator(op, l, env)
        if l.Type == "object" then
            if op == "#" then
                if l.type == "string" then
                    if l.const then
                        if l.data then
                            return types.Object:new("number", #l.data, true)
                        end
                    end
                    return types.Object:new("number")
                end

                return types.Object:new("any")
            end

            if op == "~" then
                if l.type == "number" then
                    if l.data ~= nil then
                        return types.Object:new("number", bit.bnot(l.data))
                    end

                    return types.Object:new("number")
                end

                return types.Object:new("any")
            end

            if op == "not" then
                if l:IsTruthy() and l:IsFalsy() then
                    return types.Object:new("boolean")
                end

                if l:IsTruthy() then
                    return types.Object:new("boolean", false, true)
                end

                if l:IsFalsy() then
                    return types.Object:new("boolean", true, true)
                end
            end

            if op == "-" then
                if env == "typesystem" then
                    if l.type == "number" and l.data then
                        return types.Object:new(l.type, -l.data, l.const)
                    end
                end
            end

            if syntax.CompiledPrefixOperatorFunctions[op] and l.data ~= nil and l.const then
                return types.Object:new(l.type, syntax.CompiledPrefixOperatorFunctions[op](l.data))
            end
        elseif l.Type == "dictionary" then
            if op == "not" then
                return self:CreateLuaType("boolean", false)
            end

            if op == "#" then
                if l.meta and l.meta:Get("__len") then
                    error("NYI")
                end

                return self:CreateLuaType("number", #l.data, true)
            end
        elseif l.Type == "set" then
            local set = {}

            for _, v in ipairs(self.datai) do
                local val, err = self:PrefixOperator(op, v, env)
                if not val then
                    return val, err
                end
                table.insert(set, val)
            end

            return Set:new(set)
        elseif l.Type == "tuple" then
            return self:PrefixOperator(op, v:Get(1), env)
        end

        error("unhandled prefix operator in " .. env .. ": " .. op .. tostring(l))
    end

    function META:BinaryOperator(op, l, r, env)
        if env == "typesystem" then
            if op == "|" then
                return types.Set:new({l, r})
            end

            if op == "extends" then
                return l:Extend(r)
            end

            if op == ".." then
                local new = l:Copy()
                new.max = r
                return new
            end
        end

        if l.Type == "object" and r.Type == "set" then
            return self:BinaryOperator(op, types.Set:new({l}), r, env)
        end

        if l.Type == "set" and r.Type == "object" then
            return self:BinaryOperator(op, l, types.Set:new({r}), env)
        end

        if op == "." or op == ":" then
            return self:GetOperator(l, r)
        end

        if op == "or" then
            if l:IsTruthy() and l:IsFalsy() then
                return types.Set:new({l,r})
            end

            if r:IsTruthy() and r:IsFalsy() then
                return types.Set:new({l,r})
            end

            -- when true, or returns its first argument
            if l:IsTruthy() then
                return l
            end

            if r:IsTruthy() then
                return r
            end

            return r
        end

        if op == "not" then
            if l:IsTruthy() then
                if l:IsFalsy() then
                    return Object:new("boolean")
                end

                return Object:new("boolean", false, true)
            end

            return Object:new("boolean", true, true)
        end

        if op == "and" then
            if l:IsTruthy() and r:IsFalsy() then
                if l:IsFalsy() or r:IsTruthy() then
                    return types.Set:new({l,r})
                end

                return r
            end

            if l:IsFalsy() and r:IsTruthy() then
                if l:IsTruthy() or r:IsFalsy() then
                    return types.Set:new({l,r})
                end

                return l
            end

            if l:IsTruthy() and r:IsTruthy() then
                if l:IsFalsy() and r:IsFalsy() then
                    return types.Set:new({l,r})
                end

                return r
            else
                if l:IsTruthy() and r:IsTruthy() then
                    return types.Set:new({l,r})
                end

                return l
            end
        end

        if l.meta then
            if op == "+" then
                if l.meta:Get("__add") then
                    return self:Call(l.meta:Get("__add"), types.Tuple:new({l, r}), op)[1]
                end
            end
        end

        if l.Type == "object" then
            if l.type == "number" and r.type == "number" then
                if op == "~=" then
                    if l.max and l.max.data then
                        return types.Object:new("boolean", not (r.data >= l.data and r.data <= l.max.data), true)
                    end

                    if r.max and r.max.data then
                        return types.Object:new("boolean", not (l.data >= r.data and l.data <= r.max.data), true)
                    end
                elseif op == "==" then
                    if l.max and l.max.data then
                        return types.Object:new("boolean", r.data >= l.data and r.data <= l.max.data, true)
                    end

                    if r.max and r.max.data then
                        return types.Object:new("boolean", l.data >= r.data and l.data <= r.max.data, true)
                    end
                elseif op == "%" then
                    if l:IsConst() and r:IsConst() then
                        return types.Object:new("number", l:GetData() % r:GetData())
                    end

                    local t = types.Object:new("number", 0)
                    t.max = r:Copy()

                    return t
                elseif op == "^" then
                    if l:IsConst() and r:IsConst() then
                        return types.Object:new("number", l.data ^ r.data, true)
                    end

                    return types.Object:new("number")
                elseif op == "/" then
                    if l:IsConst() and r:IsConst() then
                        return types.Object:new("number", l.data / r.data, true)
                    end

                    return types.Object:new("number")
                elseif op == "*" then
                    if l:IsConst() and r:IsConst() then
                        local res = types.Object:new(l.type, l.data * r.data, true)

                        if l.max and r.max then
                            res.max = self:BinaryOperator("*", l.max, r.max, env)
                        elseif r.max then
                            res.max = self:BinaryOperator("*", l, r.max, env)
                        elseif l.max then
                            res.max = self:BinaryOperator("*", l.max, r, env)
                        end

                        return res
                    end

                    return types.Object:new("number")
                end
            end
        end

        if op == "==" then
            if l:IsConst() and r:IsConst() then
                return types.Object:new("boolean", l.data == r.data, true)
            end

            if l.type == "nil" and r.type == "nil" then
                return types.Object:new("boolean", nil == nil, true)
            end

            if l.type ~= r.type then
                return types.Object:new("boolean", false, true)
            end

            if l == r then
                return types.Object:new("boolean", true, true)
            end

            return types.Object:new("boolean")
        elseif op == "~=" then
            if l:IsConst() and r:IsConst() then
                return types.Object:new("boolean", l.data ~= r.data, true)
            end

            if l.type == "nil" and r.type == "nil" then
                return types.Object:new("boolean", nil ~= nil, true)
            end

            if l.type ~= r.type then
                return types.Object:new("boolean", true, true)
            end

            if l == r then
                return types.Object:new("boolean", false, true)
            end

            return types.Object:new("boolean")
        end

        if op == ".." then
            if (l.type == "string" or l.type == "number") and (r.type == "string" or r.type == "number") then
                if l:IsConst() and r:IsConst() then
                    return types.Object:new("string", l.data .. r.data, l:IsConst() or r:IsConst())
                end

                return types.Object:new("string")
            end
        end

        if op == ">=" then
            if l:IsConst() and r:IsConst() then
                return types.Object:new("boolean", l.data >= r.data, true)
            end

            return types.Object:new("boolean")
        elseif op == "<=" then
            if l:IsConst() and r:IsConst() then
                return types.Object:new("boolean", l.data <= r.data, true)
            end

            return types.Object:new("boolean")
        elseif op == "<" then
            if l:IsConst() and r:IsConst() then
                return types.Object:new("boolean", l.data < r.data, true)
            end

            return types.Object:new("boolean")
        elseif op == ">" then
            if l:IsConst() and r:IsConst() then
                return types.Object:new("boolean", l.data > r.data, true)
            end

            return types.Object:new("boolean")
        end

        if syntax.CompiledBinaryOperatorFunctions[op] and l.data ~= nil and r.data ~= nil then

            if l.type ~= r.type then
                return false, "no operator for " .. tostring(l.type or l) .. " " .. op .. " " .. tostring(r.type or r)
            end

            if l.Type == "set" and r.Type == "set" then
                local new_set = types.Set:new()

                for _, l in ipairs(l:GetElements()) do
                    for _, r in ipairs(r:GetElements()) do
                        local a = assert(self:BinaryOperator(op, l, r, env))
                        new_set:AddElement(a)
                    end
                end

                return new_set
            end

            local lval = l.data
            local rval = r.data
            local type = l.type

            if l.Type == "tuple" then
                lval = l.data[1].data
                type = l.data[1].type
            end

            if r.Type == "tuple" then
                rval = r.data[1].data
            end

            return types.Object:new(type, syntax.CompiledBinaryOperatorFunctions[op](rval, lval), l:IsConst() or r:IsConst())
        end

        if l.type == r.type then
            return types.Object:new(l.type)
        end

        if l.type == "any" or r.type == "any" then
            return types.Object:new("any")
        end

        error(" NYI " .. env .. ": "..tostring(l).." "..op.. " "..tostring(r))
    end

    function META:SetOperator(obj, key, val, env)

        if obj.Type == "set" then
            local copy = types.Set:new()
            for i,v in ipairs(obj:GetElements()) do
                local ok, err = self:SetOperator(v, key, val, env)
                if not ok then
                    return ok, err
                end
                copy:AddElement(val)
            end
            return copy
        end

        if not obj.Set then
            return false, "undefined set: " .. tostring(obj) .. "[" .. tostring(key) .. "] = " .. tostring(val) .. " on type " .. obj.Type
        end

        return obj:Set(key, val)
    end

    function META:GetOperator(obj, key, env)
        if obj.Type == "set" then
            local copy = types.Set:new()
            for i,v in ipairs(obj:GetElements()) do
                local val, err = self:GetOperator(v, key)
                if not val then
                    return val, err
                end
                copy:AddElement(val)
            end
            return copy
        end

        if obj.Type ~= "dictionary" and obj.Type ~= "tuple" and (obj.Type ~= "object" or obj.type ~= "string") then
            return false, "undefined get: " .. tostring(obj) .. "[" .. tostring(key) .. "]"
        end

        if obj.contract then
            return obj:Get(key)
        end

        local val, reason = obj:Get(key)

        if not val then
            return self:TypeFromImplicitNode(obj.node, "nil")
        end

        return val
    end

    function META:CallOperator(obj, arguments, check_length)
        if obj.Type == "object" then
            if obj.type == "any" then
                return types.Tuple:new(types.Object:new("any"))
            end

            if obj.type == "function"  then
                if obj.data.lua_function then
                    _G.self = require("oh").current_analyzer
                    local res = {pcall(obj.data.lua_function, table.unpack(arguments.data))}
                    _G.self = nil

                    if not res[1] then
                        return false, res[2]
                    end

                    if not res[2] then
                        res[2] = types.Object:new("nil")
                    end

                    table.remove(res, 1)

                    for i,v in ipairs(res) do
                        if not types.IsTypeObject(v) then
                            res[i] = self:CreateLuaType(type(v), v, true)
                        end
                    end

                    return types.Tuple:new(res)
                end

                local A = arguments -- incoming
                local B = obj.data.arg -- the contract
                -- A should be a subset of B

                if check_length and A:GetLength() ~= B:GetLength() then
                    return false, "invalid amount of arguments"
                end

                for i, a in ipairs(A:GetData()) do
                    local b = B:Get(i)
                    if not b then
                        break
                    end

                    local ok, reason = a:SubsetOf(b)

                    if not ok then
                        return false, reason
                    end
                end

                return obj.data.ret
            end
        elseif obj.Type == "tuple" then
            local out = types.Set:new()

            for _, obj in ipairs(obj.data) do
                if not obj.Call then
                    return false, "set contains uncallable object " .. tostring(obj)
                end

                local return_tuple = self:CallOperator(obj, arguments)

                if return_tuple then
                    out:AddElement(return_tuple)
                end
            end

            return types.Tuple:new({out})
        elseif obj.Type == "set" then
            local set = types.Set:new()
            local errors = {}

            if not obj.datai[1] then
                return false, "cannot call empty set"
            end

            for _, obj in ipairs(obj.datai) do
                if (obj.Type == "object" and not obj:IsType("function")) then
                    return false, "set contains uncallable object " .. tostring(obj)
                end
            end

            for _, obj in ipairs(obj.datai) do
                local return_tuple, error = self:CallOperator(obj, arguments, true)

                if return_tuple then
                    return return_tuple
                else
                    table.insert(errors, error)
                end
            end

            return false, table.concat(errors, "\n")
        end

        error("undefined call:" .. tostring(obj) .. tostring(arguments))
    end
end

do -- types
    function META:CreateLuaType(type, data, const)
        if type == "table" then
            return types.Dictionary:new(data, const)
        elseif type == "..." then
            return types.Tuple:new(data)
        elseif type == "string" then
            local obj = types.Object:new(type, data, const)

            if not self.string_meta then
                local meta = self:CreateLuaType("table", {})
                meta:Set("__index", self.IndexNotFound and self:IndexNotFound("string") or self:GetValue("string", "typesystem"))
                self.string_meta = meta
            end

            obj.meta = self.string_meta

            return obj
        elseif type == "number" or type == "function" or type == "boolean" then
            return types.Object:new(type, data, const)
        elseif type == "nil" then
            return types.Object:new(type, const)
        elseif type == "any" then
            return types.Object:new(type, const)
        elseif type == "list" then
            data = data or {}
            local tup = types.Tuple:new(data.values)
            tup.ElementType = data.type
            tup.max = data.length
            return tup
        end

        error("NYI " .. type)
    end

    function META:TypeFromImplicitNode(node, name, data, const)
        node.scope = self.scope -- move this out of here

        local obj = self:CreateLuaType(name, data, const)

        if not obj then error("NYI: " .. name) end

        obj.node = node
        node.inferred_type = obj

        return obj
    end

    do
        local guesses = {
            {pattern = "count", type = "number"},
            {pattern = "tbl", type = "table"},
            {pattern = "str", type = "string"},
        }

        table.sort(guesses, function(a, b) return #a.pattern > #b.pattern end)

        function META:GetInferredType(node, env)
            local str = node.value.value:lower()

            for _, v in ipairs(guesses) do
                if str:find(v.pattern, nil, true) then
                    return self:TypeFromImplicitNode(node, v.type)
                end
            end

            if env == "typesystem" then
                return self:TypeFromImplicitNode(node, "nil")
            end

            return self:TypeFromImplicitNode(node, "any")
        end
    end

    do
        function META:Call(obj, arguments, node, deferred)
            node = node or obj.node

            --lua function
            local callable = obj.Type == "dictionary" and obj.meta and obj.meta:Get("__call")

            if callable then
                --arguments = arguments:Copy()
                local arg = obj
                arg.volatile = true
                table.insert(arguments.data, 1, arg)
                obj = callable
            end

            -- diregard arguments and use function's arguments in case they have been maniupulated (ie string.gsub)
            if deferred then
                arguments = obj:GetArguments()
            end

            -- for deferred calls
            obj.called = true

            if obj.node and (obj.node.kind == "function" or obj.node.kind == "local_function" or obj.node.kind == "local_type_function2") then

                do -- recursive guard
                    if self.calling_function == obj then
                        return (obj:GetReturnTypes() and obj:GetReturnTypes().data and obj:GetReturnTypes().data[1]) or {self:TypeFromImplicitNode(node, "any")}
                    end
                    self.calling_function = obj
                end

                local return_tuple = self:Assert(node, self:CallOperator(obj, arguments))

                local env = "runtime"

                if self.PreferTypesystem then
                    env = "typesystem"
                end

                self:PushScope(obj.node)
                    local self_call = obj.node.self_call

                    if self_call then
                        self:SetUpvalue("self", arguments:Get(1) or self:TypeFromImplicitNode(obj.node, "nil"), env)
                    end

                    for i, identifier in ipairs(obj.node.identifiers) do
                        local argi = self_call and (i+1) or i

                        if identifier.value.value == "..." then
                            local values = {}
                            for i = argi, arguments:GetLength() do
                                table.insert(values, arguments:Get(i))
                            end
                            self:SetUpvalue(identifier, self:TypeFromImplicitNode(identifier, "...", values), env)
                        else
                            self:SetUpvalue(identifier, arguments:Get(argi) or self:TypeFromImplicitNode(identifier, "nil"), env)
                        end
                    end

                    types.collected_return_tuples = types.collected_return_tuples or {}
                    table.insert(types.collected_return_tuples,  1, {})
                    local ret = types.collected_return_tuples[1]

                    -- crawl and collect return values from function statements
                    self:AnalyzeStatements(obj.node.statements)

                    table.remove(types.collected_return_tuples, 1)


                self:PopScope()

                do
                    -- copy the entire tuple so we don't modify the return value of this call
                    local ret_tuple = types.Tuple:new(ret):Copy()

                    -- if this function has an explicit return type
                    if obj.node.return_types then
                        local B = return_tuple
                        local A = ret_tuple

                        local ok, reason = A:SubsetOf(B)

                        if not ok then
                            self:Error(obj.node, reason)
                        end
                    else
                        for i,v in ipairs(ret_tuple:GetData()) do
                            v.volatile = true
                        end

                        obj:GetReturnTypes():Merge(ret_tuple)
                    end
                end

                obj:GetArguments():Merge(arguments, true)


                -- TODO
                if node.self_call then
                    local first_arg = obj:GetArguments():Get(1)
                    if first_arg and not first_arg.contract then
                        first_arg.volatile = true
                    end
                end

                for i, v in ipairs(obj:GetArguments().data) do
                    if obj.node.identifiers[i] then
                        obj.node.identifiers[i].inferred_type = v
                    end
                end

                obj.node.inferred_type = obj

                self:FireEvent("function_spec", obj)

                self.calling_function = nil

                if not ret[1] then
                    -- if this is called from CallMeLater we cannot create a nil type from node
                    local old = node.inferred_type
                    ret[1] = self:TypeFromImplicitNode(node, "nil")
                    node.inferred_type = old
                end

                return ret
            end

            self:FireEvent("external_call", node, obj)

            local ret, err = self:CallOperator(obj, arguments)

            if ret == false then
                self:Error(node, err)
            end

            return ret.data
        end
    end
end

function META:AnalyzeStatement(statement)
    self.current_statement = statement

    if statement.kind == "root" then
        self:PushScope(statement)
        local ret
        if self:AnalyzeStatements(statement.statements) == true then
            ret = true
        end
        self:PopScope()
        if self.deferred_calls then
            for _,v in ipairs(self.deferred_calls) do
                if not v[1].called then
                    self:Call(table.unpack(v))
                end
            end
        end
        return ret
    elseif statement.kind == "assignment" or statement.kind == "local_assignment" then
        local env = self.PreferTypesystem and "typesystem" or statement.environment or "runtime"
        local assignments = {}

        for i, exp_key in ipairs(statement.left) do
            if statement.kind == "local_assignment" then
                assignments[i] = {
                    key = exp_key,
                    env = env,
                }
            elseif statement.kind == "assignment" then
                if type(exp_key) == "string" or exp_key.kind == "value" then
                    assignments[i] = {
                        key = exp_key,
                        env = env,
                    }
                else
                    local obj = self:AnalyzeExpression(exp_key.left, env)
                    local key = exp_key.kind == "postfix_expression_index" and self:AnalyzeExpression(exp_key.expression, env) or self:AnalyzeExpression(exp_key.right, env)

                    assignments[i] = {
                        obj = obj,
                        key = key,
                    }
                end
            end
        end

        local values = {}

        if statement.right then
            for _, exp in ipairs(statement.right) do
                for _, obj in ipairs({self:AnalyzeExpression(exp, env)}) do

                    -- table.unpack
                    if obj.Type == "tuple" then -- vararg
                        for _, obj in ipairs(obj.data) do
                            table.insert(values, obj)
                        end
                    end

                    table.insert(values, obj)
                end
            end
        end

        for i, exp_key in ipairs(statement.left) do
            local val = values[i] or self:TypeFromImplicitNode(exp_key, "nil")

            local key = assignments[i].key
            local obj = assignments[i].obj

            -- if there's a type expression override the right value
            if exp_key.type_expression then
                local contract = self:AnalyzeExpression(exp_key.type_expression, "typesystem")

                if contract.type == "nil" then
                    -- TODO: better error
                    self:Error(exp_key.type_expression, "cannot be nil")
                end

                if statement.right and statement.right[i] then

                    if contract.Type == "dictionary" then
                        val:CopyConstness(contract)
                    else
                        -- local a: 1 = 1
                        -- should turn the right side into a constant number rather than number(1)
                        val.const = contract:IsConst()
                    end

                    local ok, reason = val:SubsetOf(contract)

                    if not ok then
                        self:Error(val.node or exp_key.type_expression, tostring(val) .. " is not a subset of " .. tostring(contract) .. " because " .. reason)
                    end
                end

                if val.type == "dictionary" and contract.type == "list" then
                    assert("NYI")
                else
                    val.contract = contract
                end

                if not values[i] then
                    val = contract
                end

                --val = contract
            else
                -- by default assignments are not constant, even though TypeFromImplicitNode is const by default
              --  val.const = false
            end

            exp_key.inferred_type = val

            if statement.kind == "local_assignment" then
                self:SetUpvalue(key, val, env)
            elseif statement.kind == "assignment" then
                if type(exp_key) == "string" or exp_key.kind == "value" then
                    self:SetValue(key, val, env)
                else
                    self:Assert(exp_key, self:SetOperator(obj, key, val, env))
                    self:FireEvent("newindex", obj, key, val, env)
                end
            end
        end

    elseif statement.kind == "destructure_assignment" or statement.kind == "local_destructure_assignment" then
        local env = statement.environment or "runtime"
        local obj = self:AnalyzeExpression(statement.right, env)

        if obj.Type ~= "dictionary" then
            self:Error(statement.right, "expected a table on the right hand side, got " .. tostring(obj))
        end

        if statement.default then
            if statement.kind == "local_destructure_assignment" then
                self:SetUpvalue(statement.default, obj, env)
            elseif statement.kind == "destructure_assignment" then
                self:SetValue(statement.default, obj, env)
            end
        end

        for _, node in ipairs(statement.left) do
            local obj = node.value and obj:Get(node.value.value, env) or self:TypeFromImplicitNode(node, "nil")

            if statement.kind == "local_destructure_assignment" then
                self:SetUpvalue(node, obj, env)
            elseif statement.kind == "destructure_assignment" then
                self:SetValue(node, obj, env)
            end
        end
    elseif statement.kind == "function" then
        self:SetValue(statement.expression, self:GetValue(statement.expression, "typesystem") or self:AnalyzeFunction(statement), "runtime")
    elseif statement.kind == "local_function" then
        self:SetUpvalue(statement.tokens["identifier"], self:AnalyzeFunction(statement), "runtime")
    elseif statement.kind == "local_type_function" or statement.kind == "local_type_function2" then
        self:SetUpvalue(statement.identifier, self:AnalyzeFunction(statement, "typesystem"), "typesystem")
    elseif statement.kind == "if" then
        for i, statements in ipairs(statement.statements) do
            if not statement.expressions[i] then
                self:PushScope(statement, statement.tokens["if/else/elseif"][i])
                self:AnalyzeStatements(statements)
                self:PopScope()
                break
            else
                local obj = self:AnalyzeExpression(statement.expressions[i], "runtime")

                if obj:IsTruthy() then
                    self:PushScope(statement, statement.tokens["if/else/elseif"][i])
                    obj:PushTruthy()

                    if self:AnalyzeStatements(statements) == true then
                        if obj.data == true then
                            obj:PopTruthy()
                            self:PopScope()
                            return true
                        end
                    end

                    obj:PopTruthy()
                    self:PopScope()
                    break
                end
            end
        end
    elseif statement.kind == "while" then
        if self:AnalyzeExpression(statement.expression):IsTruthy() then
            self:PushScope(statement)
            if self:AnalyzeStatements(statement.statements) == true then
                return true
            end
            self:PopScope()
        end
    elseif statement.kind == "do" then
        self:PushScope(statement)
        if self:AnalyzeStatements(statement.statements) == true then
            return true
        end
        self:PopScope()
    elseif statement.kind == "repeat" then
        self:PushScope(statement)
        if self:AnalyzeStatements(statement.statements) == true then
            return true
        end
        if self:AnalyzeExpression(statement.expression):IsTruthy() then
            self:FireEvent("break")
        end
        self:PopScope()
    elseif statement.kind == "return" then
        local return_values = types.collected_return_tuples[1]

        local evaluated = {}
        for i,v in ipairs(statement.expressions) do
            evaluated[i] = self:AnalyzeExpression(v)
            -- add the return values
            if return_values then
                if not return_values[i] then
                    return_values[i] = evaluated[i]
                else
                    return_values[i] = types.Union(return_values[i], evaluated[i])
                end
            end
        end

        self:FireEvent("return", evaluated)

        self.last_return = evaluated

        return true
    elseif statement.kind == "break" then
        self:FireEvent("break")
        --return true
    elseif statement.kind == "call_expression" then
        self:FireEvent("call", statement.value, {self:AnalyzeExpression(statement.value)})
    elseif statement.kind == "generic_for" then
        self:PushScope(statement)

        local args = self:AnalyzeExpressions(statement.expressions)
        local obj = args[1]

        if obj then
            table.remove(args, 1)

            local values = self:Call(obj, types.Tuple:new(args), statement.expressions[1])

            for i,v in ipairs(statement.identifiers) do
                self:SetUpvalue(v, values[i], "runtime")
            end
        end

        if self:AnalyzeStatements(statement.statements) == true then
            return true
        end

        self:PopScope()
    elseif statement.kind == "numeric_for" then
        self:PushScope(statement)
        local range = self:AnalyzeExpression(statement.expressions[1]):Max(self:AnalyzeExpression(statement.expressions[2]))
        self:SetUpvalue(statement.identifiers[1], range, "runtime")

        if statement.expressions[3] then
            self:AnalyzeExpression(statement.expressions[3])
        end

        if self:AnalyzeStatements(statement.statements) == true then
            self:PopScope()
            return true
        end
        self:PopScope()
    elseif statement.kind == "type_interface" then
        local tbl = self:GetValue(statement.key, "typesystem") or self:TypeFromImplicitNode(statement, "table", {})

        for _, exp in ipairs(statement.expressions) do
            local left = tbl:Get(exp.left.value)
            local right = self:AnalyzeExpression(exp.right, "typesystem")

            -- function overload shortcut
            if left and left.Type == "object" and left.type == "function" then
                tbl:Set(exp.left.value, types.Set:new({left, right}))
            elseif left and left.Type == "set" then
                left:AddElement(right)
            else
                tbl:Set(exp.left.value, right)
            end
        end

        self:SetUpvalue(statement.key, tbl, "typesystem")
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

do
    function META:AnalyzeExpression(exp, env)
        assert(exp and exp.type == "expression")
        env = env or "runtime"

        if self.PreferTypesystem then
            env = "typesystem"
        end

        local stack = self:CreateStack()

        for _, node in ipairs(self:ExpandExpression(exp)) do
            self.current_expression = node

            if node.type_expression then
                local val = self:AnalyzeExpression(node.type_expression, "typesystem")
                stack:Push(val)
                if node.tokens["is"] then
                    node.result_is = self:GetValue(node, env):IsType(val)
                end
            elseif node.kind == "value" then
                if (node.value.type == "letter" and node.upvalue_or_global) or node.value.value == "..." then
                    local obj

                    if env == "typesystem" then
                        if node.value.value == "any" then
                            obj = self:TypeFromImplicitNode(node, "any")
                        elseif node.value.value == "self" then
                            obj = self.current_table
                        elseif node.value.value == "inf" then
                            obj = self:TypeFromImplicitNode(node, "number", math.huge, true)
                        elseif node.value.value == "nan" then
                            obj = self:TypeFromImplicitNode(node, "number", 0/0, true)
                        end
                    end

                    if not obj then
                        -- if it's ^string, number, etc, but not string
                        if env == "typesystem" and types.IsPrimitiveType(self:Hash(node)) and not node.force_upvalue then
                            obj = self:TypeFromImplicitNode(node, node.value.value)
                        else
                            obj = self:GetValue(node, env)

                            if not obj and env == "runtime" then
                                obj = self:GetValue(node, "typesystem")
                            end
                        end
                    end


                    if not obj and self.IndexNotFound then
                        obj = self:IndexNotFound(node)
                    end

                    -- last resort, itemCount > number
                    if not obj then
                        obj = self:GetInferredType(node, env)
                    end

                    stack:Push(obj)
                elseif node.value.type == "number" then
                    stack:Push(self:TypeFromImplicitNode(node, "number", self:StringToNumber(node.value.value), true))
                elseif node.value.type == "string" then
                    stack:Push(self:TypeFromImplicitNode(node, "string", node.value.value:sub(2, -2), true))
                elseif node.value.type == "letter" then
                    stack:Push(self:TypeFromImplicitNode(node, "string", node.value.value, true))
                elseif node.value.value == "nil" then
                    stack:Push(self:TypeFromImplicitNode(node, "nil", env == "typesystem"))
                elseif node.value.value == "true" then
                    stack:Push(self:TypeFromImplicitNode(node, "boolean", true, true))
                elseif node.value.value == "false" then
                    stack:Push(self:TypeFromImplicitNode(node, "boolean", false, true))
                else
                    error("unhandled value type " .. node.value.type .. " " .. node:Render())
                end
            elseif node.kind == "function" then
                stack:Push(self:AnalyzeFunction(node))
            elseif node.kind == "table" then
                stack:Push(self:TypeFromImplicitNode(node, "table", self:AnalyzeTable(node, env), env == "typesystem"))
            elseif node.kind == "binary_operator" then
                local right, left = stack:Pop(), stack:Pop()

                if node.value.value == ":" then
                    stack:Push(left)
                end

                 stack:Push(self:Assert(node, self:BinaryOperator(node.value.value, left, right, env)))
            elseif node.kind == "prefix_operator" then
                local left = stack:Pop()
                stack:Push(self:Assert(node, self:PrefixOperator(node.value.value, left, env)))
            elseif node.kind == "postfix_operator" then
                local right = stack:Pop()
                stack:Push(self:Assert(node, self:PostfixOperator(node.value.value, right, env)))
            elseif node.kind == "postfix_expression_index" then
                local obj = stack:Pop()
                stack:Push(self:Assert(node, self:GetOperator(obj, self:AnalyzeExpression(node.expression))))
            elseif node.kind == "type_function" then
                local args = {}
                local rets = {}
                local func

                -- declaration
                if node.identifiers then
                    for i, key in ipairs(node.identifiers) do
                        if key.kind == "value" and key.value.value == "..." then
                            args[i] = self:TypeFromImplicitNode(key, "...", {self:TypeFromImplicitNode(key, "any")})
                            args[i].max = math.huge
                        elseif key.kind == "type_table" then
                            args[i] = self:AnalyzeExpression(key)
                        else
                            args[i] = self:GetValue(key.left or key, env) or (types.IsPrimitiveType(key.value.value) and self:TypeFromImplicitNode(node, key.value.value)) or self:GetInferredType(key)
                        end
                    end
                end

                if node.return_expressions then
                    for i,v in ipairs(node.return_expressions) do
                        rets[i] = self:AnalyzeExpression(v, env)
                    end
                end

                if node.statements then
                    local str = "local oh, analyzer, types, node = ...; return " .. node:Render({})
                    local load_func, err = load(str, "")
                    if not load_func then
                        -- this should never happen unless node:Render() produces bad code or the parser didn't catch any errors
                        io.write(str, "\n")
                        error(err)
                    end
                    func = load_func(require("oh"), self, types, node)
                end


                args = types.Tuple:new(args)
                rets = types.Tuple:new(rets)

                stack:Push(self:TypeFromImplicitNode(node, "function", {
                    arg = args,
                    ret = rets,
                    lua_function = func
                }))
            elseif node.kind == "postfix_call" then
                local obj = stack:Pop()

                local arguments = self:AnalyzeExpressions(node.expressions, node.type_call and "typesystem" or env)

                if node.self_call then
                    local val = stack:Pop()
                    table.insert(arguments, 1, val)
                end

                if obj.type and obj.type ~= "function" and obj.type ~= "table" and obj.type ~= "any" then
                    self:Error(node, tostring(obj) .. " cannot be called")
                else
                    self.PreferTypesystem = node.type_call
                    stack:Push(self:Call(obj, types.Tuple:new(arguments), node))
                    self.PreferTypesystem = nil
                end
            elseif node.kind == "type_list" then
                local tbl = {}

                if node.types then
                    for i, exp in ipairs(node.types)do
                        tbl[i] = self:AnalyzeExpression(exp, env)
                    end
                end

                -- number[3] << tbl only contains {3}.. hmm
                stack:Push(self:TypeFromImplicitNode(node, "list", {length = nil, values = tbl}))
            elseif node.kind == "type_table" then
                local obj = self:TypeFromImplicitNode(node, "table")

                self.current_table = obj
                for _, v in ipairs(self:AnalyzeTable(node, env)) do
                    obj:Set(v.key, v.val, true)
                end
                self.current_table = nil

                stack:Push(obj)
            elseif node.kind == "import" or node.kind == "lsx" then
                --stack:Push(self:AnalyzeStatement(node.root))
            else
                error("unhandled expression " .. node.kind)
            end
        end

        return stack:Unpack()
    end

    function META:AnalyzeFunction(node)
        local args = {}

        for i, key in ipairs(node.identifiers) do
            -- if this node is already explicitly annotated with foo: mytype or foo as mytype use that
            if key.type_expression then
                args[i] = self:AnalyzeExpression(key.type_expression, "typesystem") or self:GetInferredType(key)
            else
                if key.value.value == "..." then
                    args[i] = self:TypeFromImplicitNode(key, "...", {self:TypeFromImplicitNode(key, "any")})
                    args[i].max = math.huge
                else
                    args[i] = self:GetInferredType(key)
                end
                args[i].volatile = true
            end
        end

        if node.self_call and node.expression then
            local upvalue = self:GetUpvalue(node.expression.left, "runtime")
            if upvalue then
                -- TODO: this will cause local META = {} .. to be volatile,
                -- all the volatile things should be separated from types i think
                upvalue.data.volatile = true
                table.insert(args, 1, upvalue.data)
            end
        end


        local ret = {}

        if node.return_types then
            for i, type_exp in ipairs(node.return_types) do
                ret[i] = self:AnalyzeExpression(type_exp, "typesystem")
            end
        else
            --ret[1] = self:TypeFromImplicitNode(node, "any")
        end

        args = types.Tuple:new(args)
        ret = types.Tuple:new(ret)

        local obj = self:TypeFromImplicitNode(node, "function", {
            arg = args,
            ret = ret,
        })

        if node.kind ~= "local_type_function2" then
            self:CallMeLater(obj, args, node, true)
        end

        return obj
    end

    function META:AnalyzeTable(node, env)
        local out = {}
        for i, node in ipairs(node.children) do
            if node.kind == "table_key_value" then
                local val = self:AnalyzeExpression(node.expression, env)
                out[i] = {
                    key = node.tokens["identifier"].value,
                    val = val
                }
            elseif node.kind == "table_expression_value" then

                local key = self:AnalyzeExpression(node.expressions[1], env)
                local obj = self:AnalyzeExpression(node.expressions[2], env)


                if key:IsType("string") and key.value then
                    out[i] = {key = key.value, val = obj}
                else
                    out[i] = {key = key, val = obj}
                end
            elseif node.kind == "table_index_value" then
                local val = self:AnalyzeExpression(node.expression, env)

                if val.Type == "tuple" then
                    for i = 1, val:GetLength() do
                        table.insert(out, {
                            key = #out + 1,
                            val = val:Get(i)
                        })
                    end
                elseif node.i then
                    out[i] = {
                        key = node.i,
                        val = val
                    }
                else
                    table.insert(out, {
                        key = #out + 1,
                        val = val
                    })
                end
            end
        end
        return out
    end
end



return require("oh.analyzer")(META)