
local types = require("nattlua.types.types")
local type_errors = require("nattlua.types.error_messages")

return function(META) 
    function META:LuaTypesToTuple(node, tps)
        local tbl = {}
        
        for i,v in ipairs(tps) do
            if types.IsTypeObject(v) then
                tbl[i] = v
            else
                if type(v) == "function" then
                    tbl[i] = self:NewType(node, "function", {
                        lua_function = v, 
                        arg = types.Tuple({}):AddRemainder(types.Tuple({types.Any()}):SetRepeat(math.huge)), 
                        ret = types.Tuple({}):AddRemainder(types.Tuple({types.Any()}):SetRepeat(math.huge))
                    }, true)
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
        self:CreateAndPushFunctionScope(function_node, nil, {
            type = "function",
            function_node = function_node,
            arguments = arguments,
            env = env,
        })
        self:PushEnvironment(function_node, nil, env)
    
        if function_node.self_call then
            self:CreateLocalValue("self", arguments:Get(1) or self:NewType(function_node, "nil"), env, "self")
        end
        
        for i, identifier in ipairs(function_node.identifiers) do
            local argi = function_node.self_call and (i+1) or i
    
            if identifier.value.value == "..." then
                self:CreateLocalValue(identifier, arguments:Slice(argi), env, argi)
            else
                self:CreateLocalValue(identifier, arguments:Get(argi) or self:NewType(identifier, "nil"), env, argi)
            end
        end
    
        local analyzed_return = self:AnalyzeStatementsAndCollectReturnTypes(function_node)
        
        self:PopEnvironment(env)
        self:PopScope()
    
        return analyzed_return
    end

    local unpack_union_tuples
    do
        local d = {}
        local function get_signature(tup)
            local sig = {}
            for i,v in ipairs(tup) do
                sig[i] = v:GetSignature()
            end
            return table.concat(sig, "-")
        end
        local function done(tup)
            d[get_signature(tup)] = true
        end
        local function is_done(tup)
            return d[get_signature(tup)]
        end
    
        local function expand(args, out, function_arguments)
            local tup = {}
            for i, t in ipairs(args) do  
                local type = function_arguments:Get(i)
                
                local should_expand = t.Type == "union"

                if type.Type == "any" then
                    should_expand = false
                end

                if type.Type == "union" then
                    should_expand = false
                end

                if t.Type == "union" and type.Type == "union" and type:HasNil() then
                    should_expand = true
                end
                
                if should_expand then
                    for i2,v in ipairs(t:GetData()) do
                        local args2 = {}
                        for i, v in ipairs(args) do args2[i] = v end
                        args2[i] = v
                        expand(args2, out, function_arguments)
                    end
                else
                    table.insert(tup, t)
                end
            end
            if #tup == #args and not is_done(tup) then
                table.insert(out, tup)
                done(tup)
            end
        end

        function unpack_union_tuples(input, function_arguments)
            d = {}            
            local out = {}
            expand(input, out, function_arguments)
            return out
        end
    end

    local function infer_uncalled_functions(self, call_node, tuple, function_arguments)
        for i, b in ipairs(tuple:GetData()) do
            if b.Type == "function" and not b.called and not b.explicit_return then
                local a = function_arguments:Get(i)
        
                if a and
                    (
                        a.Type == "function" and 
                        not a:GetReturnTypes():IsSubsetOf(b:GetReturnTypes())
                    )
                        or not a:IsSubsetOf(b)
                then
                    self:Assert(call_node, self:Call(b, b:GetArguments():Copy()))
                end
            end
        end
    end

    local function call_type_function(self, obj, call_node, function_node, function_arguments, arguments)
        local len = function_arguments:GetLength()

        if len == math.huge and arguments:GetLength() == math.huge then
            len = math.max(function_arguments:GetMinimumLength(), arguments:GetMinimumLength())
        end

        local ret = {}
        for i, arg in ipairs(unpack_union_tuples({arguments:Unpack(len)}, function_arguments)) do
            ret[i] = self:LuaTypesToTuple(
                obj:GetNode(), {
                    self:CallLuaTypeFunction(
                        call_node, 
                        obj:GetData().lua_function, 
                        function_node.function_scope or self:GetScope(), 
                        table.unpack(arg)
                    )
                }
            )
        end

        local tup = types.Tuple({})

        for i, t in ipairs(ret) do
            for i,v in ipairs(t:GetData()) do
                local existing = tup:Get(i)
                if existing then
                    if existing.Type == "union" then
                        existing:AddType(v)
                    else
                        tup:Set(i, types.Union({v, existing}))
                    end
                else
                    tup:Set(i, v)
                end
            end
        end
        
        return tup
    end
    
    local function restore_mutated_types(self)
        if not self.mutated_types then return end

        for _, arg in ipairs(self.mutated_types) do
            arg:SetContract(arg.old_contract)
        end
        self.mutated_types = nil
    end


    local function check_and_setup_arguments(self, obj, arguments, contracts)
        self.mutated_types = {}

        local len = contracts:GetSafeLength(arguments)

        for i = 1, len do
            local arg, err = arguments:Get(i)
            local contract = contracts:Get(i)

            local ok, reason

            if not arg then
                if contract:IsFalsy() then
                    arg = types.Nil()
                    ok = true
                else
                    ok, reason = type_errors.other("argument #" .. i .. " expected " .. tostring(contract) .. " got nil")
                end
            elseif arg.Type == "table" and contract.Type == "table" then
                ok, reason = arg:FollowsContract(contract)
            else
                ok, reason = arg:IsSubsetOf(contract)
            end                

            if not ok then
                restore_mutated_types(self)                        
                return type_errors.other("argument #" .. i .. " " .. tostring(arg) .. ": " .. reason)
            end

            if arg.Type == "table" then
                arg.old_contract = arg:GetContract()
                arg:SetContract(contract)
                table.insert(self.mutated_types, arg)
            else
                arguments:Set(i, contract:Copy())
            end
        end

        return true
    end

    local function check_return_result(self, result, contract)
        if result.Type == "union" then
            local errors = {}

            if contract.Type == "tuple" and contract:GetLength() == 1 and contract:Get(1).Type == "union" then
                contract = contract:Get(1)
            end
            
            -- all return results must match the length
            for _, tuple in ipairs(result:GetData()) do
                if tuple:GetMinimumLength() < contract:GetMinimumLength() then
                    table.insert(errors, {tuple = tuple, msg = "returned tuple "..tostring(tuple).." of length "..tuple:GetMinimumLength().." does not match the typed tuple length " .. tostring(contract) .. " of length " .. contract:GetMinimumLength()})
                end
            end

            if errors[1] then
                for _, info in ipairs(errors) do
                    self:Error(info.tuple:GetNode(), info.msg)
                end
            end

            local errors = {}

            for _, tuple in ipairs(result:GetData()) do
                local ok, reason = tuple:IsSubsetOf(contract)
                if not ok then
                    self:Error(tuple:GetNode(), reason)
                end
            end
        else 
            if contract.Type == "tuple" and contract:Get(1).Type == "union" and contract:GetLength() == 1 then
                contract = contract:Get(1)
            end

            local ok, reason = result:IsSubsetOf(contract)
            if not ok then
                self:Error(result:GetNode(), reason)
            end
        end
    end


    local function Call(self, obj, arguments, call_node)
        call_node = call_node or obj:GetNode()
        local function_node = obj.function_body_node-- or obj:GetNode()
    
        obj.called = true
    
        local env = self.PreferTypesystem and "typesystem" or "runtime"
        
        if obj.Type == "union" then
            obj = obj:MakeCallableUnion(self, call_node)
        end
        
        if obj.Type ~= "function" then
            return obj:Call(self, arguments, call_node)
        end
        
        local function_arguments = obj:GetArguments()

        infer_uncalled_functions(self, call_node, arguments, function_arguments)

        local ok, err = obj:CheckArguments(arguments)

        if not ok then
            return ok, err
        end
    
        if self.OnFunctionCall then
            self:OnFunctionCall(obj, arguments)
        end
        
        if obj:GetData().lua_function then 
            return call_type_function(self, obj, call_node, function_node, function_arguments, arguments)
        elseif not function_node or function_node.kind == "type_function" then
            self:FireEvent("external_call", call_node, obj)
        else    
            do -- recursive guard
                obj.call_count = obj.call_count or 0
                if obj.call_count > 10 or debug.getinfo(500) then
                    local ret = obj:GetReturnTypes()
                    if ret and ret:Get(1) then
                        -- TEST ME
                        return types.Tuple({ret:Get(1)})
                    end
                    return types.Tuple({self:NewType(call_node, "any")})
                end
                obj.call_count = obj.call_count + 1
            end

            local use_contract = obj.explicit_arguments and 
                env ~= "typesystem" and 
                function_node.kind ~= "local_generics_type_function" and 
                not call_node.type_call

            if use_contract then
                local ok, err = check_and_setup_arguments(self, obj, arguments, obj:GetArguments())
                if not ok then 
                    return ok, err 
                end
            end

            local return_result = self:AnalyzeFunctionBody(function_node, arguments, env)

            restore_mutated_types(self)    
            
            -- if this function has an explicit return type
            local return_contract = obj:HasExplicitReturnTypes() and 
                obj:GetReturnTypes()
                
            if not return_contract and function_node.return_types then
                self:CreateAndPushFunctionScope(function_node, nil, {
                    type = "function_return_type"
                })        
                    return_contract = types.Tuple(self:AnalyzeExpressions(function_node.return_types, "typesystem"))
                self:PopScope()
            end
                    
            if return_contract then
                check_return_result(self, return_result, return_contract) 
            else
                obj:GetReturnTypes():Merge(return_result)

                if not obj.arguments_inferred and function_node.identifiers then
                    for i, obj in ipairs(obj:GetArguments():GetData()) do
                        if function_node.self_call then
                            -- we don't count the actual self argument
                            local node = function_node.identifiers[i + 1]
                            if node and not node.explicit_type then
                                self:Warning(node, "argument is untyped")
                            end
                        elseif function_node.identifiers[i] and not function_node.identifiers[i].explicit_type then
                            self:Warning(function_node.identifiers[i], "argument is untyped")
                        end
                    end
                end
            end

            if not use_contract then
                obj:GetArguments():Merge(arguments:Slice(1, obj:GetArguments():GetMinimumLength()))
            end
    
            self:FireEvent("function_spec", obj)
            
            if return_contract then
                -- this is so that the return type of a function can access its arguments, to generics
                -- local function foo(a: number, b: number): Foo(a, b) return a + b end
                self:CreateAndPushFunctionScope(function_node, nil, {
                    type = "function_return_type"
                })
                    for i, key in ipairs(function_node.identifiers) do
                        local arg = arguments:Get(i)
                        if arg then
                            self:CreateLocalValue(key, arguments:Get(i), "typesystem", i)
                        end
                    end
    
                    return_result = return_contract
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
    
            if not return_contract then
                return return_result
            end
        end
    
        return obj:GetReturnTypes():Copy():SetReferenceId(nil)
    end
    
    function META:Call(obj, arguments, call_node)
        self.call_stack = self.call_stack or {}
    
        table.insert(self.call_stack, {
            obj = obj,
            function_node = obj.function_body_node,
            call_node = call_node
        })

        local ok, err = Call(self, obj, arguments, call_node)
    
        table.remove(self.call_stack)
    
        return ok, err
    end
end