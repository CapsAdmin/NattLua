-- this turns out to be really hard so I'm trying 
-- naive approaches while writing tests

local types = require("nattlua.types.types")
local MutationTracker = require("nattlua.analyzer.mutation_tracker")

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

    local function cast_key(key)
        if type(key) == "string" then
            return key
        end

        if type(key) == "table" then
            if key.type == "expression" and key.kind == "value" then
                return key.value.value
            elseif key.type == "letter" then
                return key.value
            else
                return key:GetData()
            end
        end

        error("aaaa")
    end

    function META:GetMutatedValue(obj, key, value) 
        local scope = self:GetScope()
        if scope:IsReadOnly() then return value end
        
        key = cast_key(key)

        if obj.mutations and obj.mutations[key] then
            return obj.mutations[key]:GetValueFromScope(scope, obj, key) or value
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

    function META:MutateValue(obj, key, val, env)
        if env == "typesystem" then return end
        local scope = self:GetScope()
        if scope:IsReadOnly() then return end
        
        key = cast_key(key)
        
        val.upvalue = obj
        val.upvalue_keyref = key

        obj.mutations = obj.mutations or {}
        obj.mutations[key] = obj.mutations[key] or MutationTracker()

        if not obj.mutations[key]:HasMutations() then
            if obj.Type == "table" then
                local uv, creation_scope = scope:FindUpvalueFromObject(obj:GetRoot(), env)
                if not creation_scope then
                    creation_scope = scope:GetRoot()
                end

                local val = (obj.contract or obj):Get(key) or types.Nil:Copy()
                val.upvalue = obj.mutations[key]
                val.upvalue_keyref = key

                obj.mutations[key]:Mutate(val, creation_scope)
            else
                obj.mutations[key]:Mutate(val, scope)
            end
        end

        obj.mutations[key]:Mutate(val, scope)
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