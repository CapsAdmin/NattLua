-- this turns out to be really hard so I'm trying 
-- naive approaches while writing tests

local types = require("nattlua.types.types")

return function(META)
    function META:AnalyzeStatements(statements)
        for i, statement in ipairs(statements) do
            self:AnalyzeStatement(statement)

            if self:GetScope():DidReturn() then
                self:GetScope():ClearReturn()
                break
            end
        end
    end

    function META:AnalyzeStatementsAndCollectReturnTypes(statement)
        local scope = self:GetScope()
        scope:MakeFunctionScope()

        self:AnalyzeStatements(statement.statements)

        local out = {}

        for _, ret in ipairs(scope:GetReturnTypes()) do
            for i, obj in ipairs(ret) do
                if out[i] then
                    out[i] = types.Union({out[i], obj})
                else
                    out[i] = obj
                end
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
        scope:CollectReturnTypes(types)
        scope:Return(scope:IsUncertain())
    end
    
    function META:OnEnterNumericForLoop(scope, init, max)
        scope:MakeUncertain(not init:IsLiteral() or not max:IsLiteral())
    end

    function META:OnFindEnvironmentValue(g, key, env)
        
    end

    function META:OnFindLocalValue(upvalue, key, env, scope)    
        local value = upvalue:GetValue()
        local scope = scope or self:GetScope()

        if scope:IsReadOnly() then return upvalue.data end

        if upvalue.mutations then

            local function resolve(from, scope)

                do
                    local mutations = {}


                    local function belongs_to_right_if_clause(subject, scope)
                        if subject.if_statement and subject.if_statement == scope.if_statement then
                            return subject == scope
                        end

                        return true
                    end

                    do
                        local current_scope-- = upvalue.mutations[1].scope
                        for i, mutation in ipairs(upvalue.mutations) do
                            do -- longest match backwards to same scope
                                local from = #mutations

                                for i = #mutations, 1, -1 do
                                    if mutations[i].scope == mutation.scope then
                                        for i = i, from do 
                                            mutations[i].remove_me = true 
                                        end
                                        break
                                    end
                                end

                                for i = #mutations, 1, -1 do
                                    if mutations[i].remove_me then
                                        table.remove(mutations, i)
                                    end
                                end
                            end
                            
                            table.insert(mutations, mutation)                            
                        end

                        -- remove scopes that are related to this if clause
                        if scope.if_statement then
                            for i = #mutations, 1, -1 do
                                if mutations[i].scope.if_statement == scope.if_statement and scope ~= mutations[i].scope then
                                    table.remove(mutations, i)
                                end
                            end
                        end

                        do -- remove anything before the last else part
                            local found_else = false
                            for i = #mutations, 1, -1 do
                                local change = mutations[i]

                                if change.scope.if_statement and change.scope.test_condition_inverted then
                                    
                                    local start = i
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
                                if a.scope.test_condition and b.scope.test_condition and a ~= b then
                                    if types.FindInType(a.scope.test_condition, b.scope.test_condition) then
                                        a.linked_mutations = a.linked_mutations or {}
                                        table.insert(a.linked_mutations, b)

                                        
                                        if types.FindInType(a.scope.test_condition, value) then
                                   --         a.certain_override = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    local union = types.Union({})
                    union.upvalue = upvalue
                    
                    for _, change in ipairs(mutations) do
                        if change.scope:IsCertain(scope) then
                            union:Clear()
                        end

                        if _ == 1 and change.value.Type == "union" then
                            union = change.value--:Copy()
                        else
                            union:AddType(change.value)
                        end
                    end

                    return union
                end
            end
            
            local union = resolve(#upvalue.mutations, scope)
            
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

            local scope = scope:FindScopeFromTestCondition(value)
            
            if scope then 
                local t
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

    function META:OnMutateUpvalue(upvalue, key, val, env)
        local scope = self:GetScope()
        if scope:IsReadOnly() then return end
        val.upvalue = upvalue
        upvalue.mutations = upvalue.mutations or {}

        table.insert(upvalue.mutations, {
            scope = scope,
            value = val,
            env = env,
        })
    end

    function META:OnMutateEnvironment(g, key, val, env)
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
                local copy = self:CloneCurrentScope()
                copy:SetTestCondition(exited_scope:GetTestCondition())
            end
        end
    
        self:FireEvent("leave_conditional_scope", current_scope, exited_scope, data)
    end
end