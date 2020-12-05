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
        if upvalue.data.Type == "union" then
            --[[

                this is only for when unions have been tested for

                local x = true | false

                if 
                    x -- x is split into a falsy and truthy union in the binary operator
                then
                    print(x) -- x is true here
                end
    
            ]]
            local scope = scope:FindScopeFromTestCondition(upvalue.data)

            if scope then
                local copy = self:CopyUpvalue(upvalue)

                if scope.test_condition_inverted then
                    copy.data = (scope.test_condition.falsy_union or copy.data:GetFalsy()):Copy()
                else
                    copy.data = (scope.test_condition.truthy_union or copy.data:GetTruthy()):Copy()
                end

                return copy
            end
        end

        if upvalue.conditions then
            local union = types.Union({})
            
            local if_else_balance = 0

            -- if part
            for cond, v in pairs(upvalue.conditions.truthy) do
                if_else_balance = if_else_balance + 1
                if not scope.test_condition_inverted or cond ~= scope.test_condition then
                    union:AddType(v)
                end
            end

            -- else part
            for cond, v in pairs(upvalue.conditions.falsy) do
                if_else_balance = if_else_balance - 1
                union:AddType(v)
            end

            -- if the balance is not 0
            if if_else_balance ~= 0 then
                union:AddType(
                    not scope.test_condition_inverted and upvalue.conditions.truthy[scope.test_condition] or 
                    upvalue.data
                )
            end
        
            return self:CopyUpvalue(upvalue, union)
        end

        return upvalue
    end

    function META:OnEnterConditionalScope(data)
        local scope = self:GetScope()
        self:FireEvent("enter_conditional_scope", scope, data)

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
        if not scope:IsUncertain() then return end

        self:CreateLocalValue(key, val, env)
    
        upvalue.conditions = upvalue.conditions or {truthy = {}, falsy = {}}

        if scope.test_condition_inverted then
            upvalue.conditions.falsy[scope.test_condition] = val
        else
            upvalue.conditions.truthy[scope.test_condition] = val
        end

        return true
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