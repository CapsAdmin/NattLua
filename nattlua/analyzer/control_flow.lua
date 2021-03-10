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

        local union = types.Union({})
    
        for i, ret in ipairs(scope:GetReturnTypes()) do
            local tup = types.Tuple(ret.types)
            tup:SetNode(ret.node)
            union:AddType(tup)
        end

        if scope.uncertain_function_return or #scope:GetReturnTypes() == 0 then
            local tup = types.Tuple({types.Nil()})
            tup:SetNode(statement)
            union:AddType(tup)
        end

        scope:ClearReturnTypes()

        if #union:GetData() == 1 then
            return union:GetData()[1]
        end

        return union
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

    function META:ThrowError(msg, obj, no_report)
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

        if not no_report then
            self:Error(self.current_statement, msg)
        end
    end

    function META:Return(node, types)
        local scope = self:GetScope()

        if not scope:IsReadOnly()  then
            local function_scope = scope:GetNearestFunctionScope()
            if scope:IsUncertain() then
                function_scope.uncertain_function_return = true
                
                -- else always hits, so even if the else part is uncertain
                -- it does mean that this function at least returns something
                if scope.is_else then
                    function_scope.uncertain_function_return = false
                end

            elseif function_scope.uncertain_function_return then
                function_scope.uncertain_function_return = false
            end
        end

        scope:CollectReturnTypes(node, types)
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
            elseif key.Type == "string" and key:IsLiteral() then
                return key:GetData()
            elseif key.Type == "number" and key:IsLiteral() then
                return key:GetData()
            end
        end
    end

    local function initialize_mutation_tracker(obj, scope, key, env)
        obj.mutations = obj.mutations or {}
        obj.mutations[key] = obj.mutations[key] or MutationTracker()

        if not obj.mutations[key]:HasMutations() then
            if obj.Type == "table" then
                local uv, creation_scope = scope:FindUpvalueFromObject(obj:GetRoot(), env)
                if not creation_scope then
                    creation_scope = scope:GetRoot()
                end

                local val = (obj:GetContract() or obj):Get(key) or types.Nil()
                val.upvalue = obj.mutations[key]
                val.upvalue_keyref = key

                obj.mutations[key]:Mutate(val, creation_scope)
            end
        end
    end

    function META:GetMutatedValue(obj, key, value, env)
        if env == "typesystem" then return end
        if obj.Type == "list" then return end
        
        local scope = self:GetScope()
        if scope:IsReadOnly() then return value end
        
        key = cast_key(key)

        if not key then
            return value
        end

        initialize_mutation_tracker(obj, scope, key, env)
        
        return obj.mutations[key]:GetValueFromScope(scope, obj, key, self) or value
    end

    function META:OnEnterConditionalScope(data)
        local scope = self:GetScope()
        scope.if_statement = data.type == "if" and data.statement
        scope.is_else = data.is_else
        scope:SetTestCondition(data.condition, data.is_else)
        scope:MakeUncertain(data.condition:IsUncertain())
    end

    function META:ErrorAndCloneCurrentScope(node, err, condition)
        self:Error(node, err)
        self:CloneCurrentScope()
        self:GetScope():SetTestCondition(condition)
    end

    function META:MutateValue(obj, key, val, env)
        if env == "typesystem" then return end
        local scope = self:GetScope()
        if scope:IsReadOnly() then return end
        
        key = cast_key(key)

        if not key then return end -- no mutation?
        
        val.upvalue = obj
        val.upvalue_keyref = key

        initialize_mutation_tracker(obj, scope, key, env)

        obj.mutations[key]:Mutate(val, scope)
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
    end
end