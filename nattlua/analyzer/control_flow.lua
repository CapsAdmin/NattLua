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

        if upvalue.mutations then

            local function resolve(from, scope)
                local union = types.Union({})
                union.upvalue = upvalue
                local i = from
                while true do
                    local change = upvalue.mutations[i]
                    if not change then break end
                    
                    if change.scope ~= scope then
                        local val, i2 = resolve(i, change.scope)
                        union:AddType(val)
                    else
                        union:AddType(change.value)              
                    end
                
                    i = i - 1
                    
                    if change.scope:IsCertain(scope) then
                        print("BREAK")
                        break
                    end
                end


                print(from, i, scope, union)
                return union, i
            end
            
            print("resolving")
            for i,v in ipairs(upvalue.mutations) do
                print(i, v.resolved or v.value)
            end
            print("==")
            
            local union = resolve(#upvalue.mutations, scope)
            
            --[[
            for i = #upvalue.mutations, 1, -1 do
                local change = upvalue.mutations[i]
                
                if change.scope.if_statement and in_if ~= change.scope.if_statement then
                    in_if = false
                end

                if last_scope ~= change.scope and not change.scope.if_statement then
                    union:AddType(change.value)
                end

                in_if = change.scope.if_statement
                last_scope = change.scope
                
                if not change.scope:IsUncertain() or change.scope == scope then
                    break
                end
            end
            ]]

            if union:Get(1) then
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
                if scope.test_condition_inverted then
                    return scope.test_condition.falsy_union or value:GetFalsy()
                else
                    return scope.test_condition.truthy_union or value:GetTruthy()
                end
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