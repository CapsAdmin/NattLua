-- this turns out to be really hard so I'm trying 
-- naive approaches while writing tests

local types = require("nattlua.types.types")

return function(META)
    function META:Return(types)
        local scope = self:GetScope()
        scope:CollectReturnTypes(types)
        scope:Return(scope:IsUncertain())
    end

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

    function META:OnEnterScope(data)
        if not data or not data.condition then return end
        
        local scope = self:GetScope()

        scope.test_condition = data.condition

        if data.is_else then
            scope.test_condition_inverted = true
        end

        scope:MakeUncertain(data.condition:IsUncertain())
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
            copy.test_condition = obj
        else
            self.lua_error_thrown = msg
        end
    end

    function META:OnExitScope(data)
        local exited_scope = self:GetLastScope()
        -- body
        
        local current_scope = self:GetScope()
        if current_scope:DidReturn() or self.lua_error_thrown or self.lua_assert_error_thrown then
            current_scope:MakeUncertain(exited_scope:IsUncertain())
            
            if exited_scope:IsUncertain() then
                local copy = self:CloneCurrentScope()
                copy.test_condition = exited_scope.test_condition
                copy.test_condition_inverted = true
            end
        end
        
        if data.type ~= "if" then
            self:MakeUncertainDataOutsideInParentScopes()
        end
    end

    function META:OnLeaveIfStatement()
        -- this has to be done after all if blocks have been processed
        self:MakeUncertainDataOutsideInParentScopes()
    end
    
    function META:OnEnterNumericForLoop(scope, init, max)
        scope:MakeUncertain(not init:IsLiteral() or not max:IsLiteral())
    end

    function META:OnFindLocalValue(upvalue, key, env, scope)
        if upvalue.data.Type == "union" then
            local scope = scope:FindScopeFromTestCondition(upvalue.data)

            if scope then
                local copy = self:CopyUpvalue(upvalue)

                if scope.test_condition_inverted then
                    copy.data = (scope.test_condition.falsy_union or copy.data:GetFalsy()):Copy()
                else
                    copy.data = (scope.test_condition.truthy_union or copy.data:GetTruthy()):Copy()
                end

                copy.original = upvalue.data

                return copy
            end
        end

        return upvalue
    end

    function META:OnMutateUpvalue(upvalue, key, val, env)
        if self:GetScope():IsUncertain() then
            --[[
                local x = false -- << shadowed upvalue

                if maybe then
                    -- uncertain scope

                    -- instead of mutating the upvalue, create a new one
                    x = true

                    -- then turn the shadowed upvalue into a union of true | false
                else
                    !! but x should not be true | false here !!
                end

            ]]

            -- new upvalue
            self:CreateLocalValue(key, val, env)

            -- mutate shadowed upvalue
            if self:GetScope().test_condition_inverted and upvalue.data_outside_of_if_blocks then
                -- if we're in an uncertain else block, 
                -- we remove the original shadowed upvalue from the union
                -- because it has to be either true or false

                upvalue.data_outside_of_if_blocks:AddType(val)
                upvalue.data_outside_of_if_blocks:RemoveType(upvalue.data)
            else
                upvalue.data_outside_of_if_blocks = types.Union({upvalue.data, val})
            end

            return true
        end
    end
end