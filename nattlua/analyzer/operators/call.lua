
local types = require("nattlua.types.types")

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
        self:CreateAndPushScope(function_node, nil, {
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
    
    local function Call(self, obj, arguments, call_node)
        call_node = call_node or obj.node
        local function_node = obj.function_body_node-- or obj.node
    
        obj.called = true
    
        local env = self.PreferTypesystem and "typesystem" or "runtime"
        
        if obj.Type == "union" then
            obj = obj:MakeCallableUnion(self, call_node)
        end
        
        if obj.Type ~= "function" then
            return obj:Call(self, arguments, call_node)
        end
        
        local function_arguments = obj:GetArguments()
    
        -- if the arguments passed are not called we need to crawl them to check its return type
        for i, b in ipairs(arguments:GetData()) do
            if b.Type == "function" and not b.called and not b.explicit_return then
                local a = function_arguments:Get(i)
    
                if a and
                    (
                        a.Type == "function" and 
                        not a:GetReturnTypes():IsSubsetOf(b:GetReturnTypes())
                    )
                        or not a:IsSubsetOf(b)
                then
                    self:Call(b, b:GetArguments():Copy())
                end
            end
        end
    
        local ok, err = obj:CheckArguments(arguments)
    
        if not ok then
            return ok, err
        end
    
        if self.OnFunctionCall then
            self:OnFunctionCall(obj, arguments)
        end
        
        if obj.data.lua_function then 
            local len = function_arguments:GetLength()
            local res
            if len == math.huge and arguments:GetLength() == math.huge then
                local longest = math.max(function_arguments:GetMinimumLength(), arguments:GetMinimumLength())
                res = {self:CallLuaTypeFunction(call_node, obj.data.lua_function, arguments:Copy():Unpack(longest))}
            else
                res = {self:CallLuaTypeFunction(call_node, obj.data.lua_function, arguments:Unpack(len))}
            end
    
            return self:LuaTypesToTuple(obj.node, res)
        elseif not function_node or function_node.kind == "type_function" then
            self:FireEvent("external_call", call_node, obj)
        else
            if not function_node.statements then
                -- TEST ME
                return types.errors.other("cannot call "..tostring(function_node:Render()).." because it has no statements")
            end
    
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
                    local ok, reason = return_tuple:IsSubsetOf(obj:GetReturnTypes())
                    if not ok then
                        return ok, reason
                    end
                else
                    obj:GetReturnTypes():Merge(return_tuple)
                end
            end
    
            obj:GetArguments():Merge(arguments)
    
            self:FireEvent("function_spec", obj)
    
            -- this is so that the return type of a function can access its arguments, to generics
            -- local function foo(a: number, b: number): Foo(a, b) return a + b end
            if function_node.return_types then
                self:CreateAndPushScope(function_node, nil, {
                    type = "function_return_type"
                })
                    for i, key in ipairs(function_node.identifiers) do
                        self:CreateLocalValue(key, arguments:Get(i), "typesystem", i)
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
    
            if not function_node.return_types then
                return return_tuple
            end
        end
    
        return obj:GetReturnTypes():Copy():SetReferenceId(nil)
    end
    
    function META:Call(obj, arguments, call_node)
        self.call_stack = self.call_stack or {}
    
        table.insert(self.call_stack, {
            obj = obj,
            func = call_node,
            call_expression = call_node
        })
    
        local ok, err = Call(self, obj, arguments, call_node)
    
        table.remove(self.call_stack)
    
        return ok, err
    end
end