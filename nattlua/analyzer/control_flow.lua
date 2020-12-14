-- this turns out to be really hard so I'm trying 
-- naive approaches while writing tests

local types = require("nattlua.types.types")

return function(META)
    function META:AnalyzeStatements(statements)
        for _, statement in ipairs(statements) do
            self:AnalyzeStatement(statement)
            
            if self.break_out_scope or self._continue_ then 
                self:FireEvent(self.break_out_scope and "break" or "continue")
                break
            end

            if self:GetScope():DidReturn() then
                self:GetScope():ClearReturn()
                break
            end
        end
    end

    function META:AnalyzeContinueStatement(statement)
        self._continue_ = true
    end

    function META:AnalyzeStatementsAndCollectReturnTypes(statement)
        local scope = self:GetScope()
        scope:MakeFunctionScope()

        self:AnalyzeStatements(statement.statements)

        local out = {}

        local longest = 0
        for i, ret in ipairs(scope:GetReturnTypes()) do
            longest = math.max(longest, #ret)
        end

        for _, ret in ipairs(scope:GetReturnTypes()) do
            for i = 1, longest do
                local obj = ret[i] or self:NewType(statement, "nil")
            
                if out[i] then
                    out[i] = types.Union({out[i], obj})
                else
                    out[i] = obj
                end
            end
        end

        if scope.uncertain_function_return then
            local obj = types.Nil:Copy()
            if out[1] then
                out[1] = types.Union({out[1], obj})
            else
                out[1] = obj
            end
        end

        scope:ClearReturnTypes()

        return types.Tuple(out)
    end

    function META:OnFunctionCall(obj, arguments)
        for i = 1, arguments:GetMinimumLength() do
            local arg = obj:GetArguments():Get(i)
            if arg and arg.out then
                local upvalue = arguments:Get(i).upvalue
                if upvalue then
                    self:SetLocalOrEnvironmentValue(upvalue.key, arguments:Get(i):Copy():MakeUnique(true), "runtime")
                end
            end
        end
    end

    function META:ThrowError(msg, obj)
        if obj then
            self.lua_assert_error_thrown = {
                msg = msg,
                obj = obj,
            }
            
            self:GetScope():Return(obj:IsTruthy())
            local copy = self:CloneCurrentScope()
            copy:MakeUncertain(obj:IsTruthy())
            copy:SetTestCondition(obj)
        else
            self.lua_error_thrown = msg
        end

        self:ReportDiagnostic(self.current_statement, msg)
    end

    function META:Return(types)
        local scope = self:GetScope()

        if not scope:IsReadOnly()  then
            local function_scope = scope:GetNearestFunctionScope()
            if scope:IsUncertain() then
                function_scope.uncertain_function_return = true
            elseif function_scope.uncertain_function_return then
                function_scope.uncertain_function_return = false
            end
        end

        scope:CollectReturnTypes(types)
        scope:Return(scope:IsUncertain())
    end
    
    function META:OnEnterNumericForLoop(scope, init, max)
        scope:MakeUncertain(not init:IsLiteral() or not max:IsLiteral())
    end

    function META:OnFindEnvironmentValue(g, key, env)
        
    end

    local function cast_key(key)
        if type(key) == "string" then
            return key
        end

        if type(key) == "table" then
            if key.type == "expression" and key.kind == "value" then
                return key.value.value
            else
                return key:GetData()
            end
        end

        error("aaaa")
    end

    function META:OnFindLocalValue(upvalue, key, value, env, scope)    
        if env == "typesystem" then return end
        scope = scope or self:GetScope()
        if scope:IsReadOnly() then return value end
        
        key = cast_key(key)
        
        if upvalue.mutations and upvalue.mutations[key] then
            local mutations = {}

            do
                for from, mutation in ipairs(upvalue.mutations[key]) do
                    do --[[
                        Remove redundant mutations that happen in the same same scope. 
                        The last mutation is the one that matters.

                        local a = 1 --<< from here
                        
                        if true then
                            a = 6
                            do a = 100 end
                            a = 2
                        end

                        a = 2 --<< to here

                    ]]
                        for i = #mutations, 1, -1 do
                            if mutations[i].scope == mutation.scope then
                                for i = from, i, -1 do 
                                    table.remove(mutations, i)    
                                end
                                break
                            end
                        end
                    end

                    -- if we're inside an if statement, we know for sure that the other parts of that if statements have not been hit
                    if scope.if_statement and mutation.scope.if_statement == scope.if_statement and scope ~= mutation.scope then
                    else 
                        table.insert(mutations, mutation)                            
                    end
                end

                do --[[
                    if mutations occured in an if statement that has an else part, remove all mutations before the if statement
    
                ]] 
                    for i = #mutations, 1, -1 do
                        local change = mutations[i]

                        if change.scope.if_statement and change.scope.test_condition_inverted then
                            
                            local statement = change.scope.if_statement
                            while true do
                                local change = mutations[i]
                                if not change then break end
                                if change.scope.if_statement ~= statement then
                                    for i = i, 1, -1 do
                                        table.remove(mutations, i)
                                    end
                                    break
                                end                                       
                            
                                i = i - 1
                            end

                            break
                        end
                    end
                end
                
                -- if the same reference type is used in a condition, all conditions must be either true or false at the same time
                for _, a in ipairs(mutations) do
                    for _, b in ipairs(mutations) do
                        if a.scope.test_condition and b.scope.test_condition then
                            if types.FindInType(a.scope.test_condition, b.scope.test_condition) then
                                a.linked_mutations = a.linked_mutations or {}
                                table.insert(a.linked_mutations, b)
                            end
                        end
                    end
                end

                if scope.test_condition then -- make scopes that use the same type condition certrain
                    for _, change in ipairs(mutations) do
                        if change.scope ~= scope and change.scope.test_condition and types.FindInType(change.scope.test_condition, scope.test_condition) then
                            change.certain_override = true
                        end
                    end
                end
            end
            
            local union = types.Union({})
            union.upvalue = upvalue
            union.upvalue_keyref = key
         
            for _, change in ipairs(mutations) do
        
                
                do
                    local current_scope = scope
                    local scope = change.scope:FindScopeFromTestCondition(change.value)
                    if scope and change.scope == scope and scope.test_condition.Type == "union" then
                        local t
                        if scope.test_condition_inverted then
                            t = scope.test_condition.falsy_union or scope.test_condition:GetFalsy()
                        else
                            t = scope.test_condition.truthy_union or scope.test_condition:GetTruthy()
                        end

                        if t then
                            union:RemoveType(t)
                        end
                    end
                end
            
                if change.certain_override or change.scope:IsCertain(scope) then
                    union:Clear()
                end

                if _ == 1 and change.value.Type == "union" then
                    if upvalue.Type == "table" then
                        union = change.value:Copy()
                        union.upvalue = upvalue
                        union.upvalue_keyref = key
                    else 
                        union = change.value:Copy()
                        union.upvalue = upvalue
                        union.upvalue_keyref = key
                    end
                else
                    union:AddType(change.value)
                end
            end
            
            if #union:GetData() == 1 then
                value = union:GetData()[1]
            else
                value = union
            end
            
        end


        if value.Type == "union" then
            --[[

                this is only for when unions have been tested for

                local x = true | false

                if 
                    x -- x is split into a falsy and truthy union in the binary operator
                then
                    print(x) -- x is true here
                end
            ]]
            
            local current_scope = scope
            local scope = scope:FindScopeFromTestCondition(value)

            if scope then 

                local current_scope = scope

                if #upvalue.mutations[key] > 1 then
                    for i = #upvalue.mutations[key], 1, -1 do
                        if upvalue.mutations[key][i].scope == current_scope then
                            return value
                        else
                            break
                        end
                    end
                end
         

                local t

                -- the or part here refers to if *condition* then
                -- truthy/falsy_union is only created from binary operators and some others
                if scope.test_condition_inverted then
                    t = scope.test_condition.falsy_union or value:GetFalsy()
                else
                    t = scope.test_condition.truthy_union or value:GetTruthy()
                end
                return t
            end
        end

        return value
    end

    function META:OnEnterConditionalScope(data)
        local scope = self:GetScope()
        self:FireEvent("enter_conditional_scope", scope, data)
        scope.if_statement = data.type == "if" and data.statement
        scope:SetTestCondition(data.condition, data.is_else)
        scope:MakeUncertain(data.condition:IsUncertain())
    end

    function META:ErrorAndCloneCurrentScope(node, err, condition)
        self:ReportDiagnostic(node, err)
        self:CloneCurrentScope()
        self:GetScope():SetTestCondition(condition)
    end

    function META:OnMutateUpvalue(upvalue, key, val, env, scope)
        if env == "typesystem" then return end
        scope = scope or self:GetScope()
        if scope:IsReadOnly() then return end
        
        key = cast_key(key)
        
        val.upvalue = upvalue
        val.upvalue_keyref = key

        upvalue.mutations = upvalue.mutations or {}
        upvalue.mutations[key] = upvalue.mutations[key] or {}

        if upvalue.Type == "table" then
            if not upvalue.mutations[key][1] then
                local uv, creation_scope = scope:FindUpvalueFromObject(upvalue:GetRoot(), env)
                if not creation_scope then
                    creation_scope = scope:GetRoot()
                end

                local val =(upvalue.contract or upvalue):Get(key) or types.Nil:Copy()
                val.upvalue = upvalue.mutations[key]
                val.upvalue_keyref = key

                table.insert(upvalue.mutations[key], {
                    scope = creation_scope,
                    value = val,
                    env = env,
                })
            end
        end

        table.insert(upvalue.mutations[key], {
            scope = scope,
            value = val,
            env = env,
        })
    end

    function META:OnMutateEnvironment(g, key, val, env)
        assert(env)
        local scope = self:GetScope()
        if not scope:IsUncertain() then return end

        if g:Contains(key) then
            self:Assert(key, g:Set(key, types.Union({g:Get(key), val})))
        end

        return true
    end

    function META:OnExitConditionalScope(data)
        local exited_scope = self:GetLastScope()
        local current_scope = self:GetScope()
        
        if current_scope:DidReturn() or self.lua_error_thrown or self.lua_assert_error_thrown then
            current_scope:MakeUncertain(exited_scope:IsUncertain())
            
            if exited_scope:IsUncertain() then
                local copy = self:CloneCurrentScope(true)
                copy:SetTestCondition(exited_scope:GetTestCondition())
            end
        end
    
        self:FireEvent("leave_conditional_scope", current_scope, exited_scope, data)
    end
end