local LexicalScope = require("nattlua.other.lexical_scope")
local types = require("nattlua.types.types")

return function(META)
    table.insert(META.OnInitialize, function(self) 
        self.default_environment = {runtime = types.Table({}), typesystem = types.Table({})}
        self.environments = {runtime = {}, typesystem = {}}
        self.scope_stack = {}
    end)

    function META:Hash(node)
        if type(node) == "string" then
            return node
        end

        if type(node.value) == "string" then
            return node.value
        end

        return node.value.value
    end

    function META:PushScope(scope, event_data)
        table.insert(self.scope_stack, self.scope)

        self.scope = scope

        self:FireEvent("enter_scope", scope, event_data)

        if self.OnEnterScope then
            self:OnEnterScope(event_data)
        end

        return scope
    end

    function META:CreateAndPushFunctionScope(node, event_data)
        return self:PushScope(LexicalScope(node and node.function_scope or self:GetScope()), event_data)
    end

    function META:CreateAndPushScope(event_data)
        return self:PushScope(LexicalScope(self:GetScope()), event_data)
    end

    function META:PopScope(event_data)
        local old = table.remove(self.scope_stack)

        self:FireEvent("leave_scope", self:GetScope().node, old, event_data)

        if old then
            self.last_scope = self:GetScope()
            self.scope = old
        end

        if event_data and self.OnExitScope then
            self:OnExitScope(event_data)
        end
    end

    function META:GetLastScope()
        return self.last_scope or self.scope
    end

    function META:GetScope()
        return self.scope
    end

    function META:GetScopeStack()
        return self.scope_stack
    end

    function META:CloneCurrentScope()
        local current_scope = self:GetScope()
        self:PopScope()
        local scope = current_scope:Copy()
        
        local parent = self:GetScope()

        if parent then
            scope:SetParent(parent)
        end

        return self:PushScope(scope)
    end

    function META:ErrorAndCloneCurrentScope(node, err, condition)
        self:ReportDiagnostic(node, err)
        self:CloneCurrentScope()
        self:GetScope().test_condition = condition
    end

    function META:CopyUpvalue(upvalue, data)
        return {
            data = data or upvalue.data:Copy(),
            key = upvalue.key,
            shadow = upvalue.shadow,
        }
    end

    function META:CreateLocalValue(key, obj, env, function_argument)
        local upvalue = self:GetScope():CreateValue(key, obj, env)
        obj.upvalue = upvalue
        self:FireEvent("upvalue", key, obj, env, function_argument)
        return upvalue
    end

    function META:OnFindLocalValue(found, key, env, original_scope)
        
    end

    function META:OnCreateLocalValue(upvalue, key, val, env)
        
    end

    function META:FindLocalValue(key, env, scope)
        if not self:GetScope() then return end
                
        local found, scope = (scope or self:GetScope()):FindValue(key, env)
        
        if found then
            local t = self:OnFindLocalValue(found, key, env, scope)
            return t or found, scope
        end
    end

    function META:SetEnvironmentOverride(node, obj, env)
        if not obj then
            if not env then
                node.environments_override = nil
            else
                node.environments_override[env] = nil
            end
        else
            node.environments_override = node.environments_override or {}
            node.environments_override[env] = obj
        end
    end

    function META:GetEnvironmentOverride(node, env)
        if node.environments_override then
            return node.environments_override[env]
        end
    end

    function META:SetDefaultEnvironment(obj, env)
        self.default_environment[env] = obj
    end

    function META:PushEnvironment(node, obj, env)
        obj = obj or self.default_environment[env]

        if #self.environments[env] == 0 then
            -- this is needed for when calling GetLocalOrEnvironmentValue when analysis is done
            -- it's mostly useful for tests, but maybe a better solution can be done here
            self.first_environment = self.first_environment or {}
            self.first_environment[env] = obj
        end

        table.insert(self.environments[env], 1, obj)

        node.environments = node.environments or {}
        node.environments[env] = obj

        self.environment_nodes = self.environment_nodes or {}
        table.insert(self.environment_nodes, 1, node)
    end

    function META:PopEnvironment(env)
        table.remove(self.environment_nodes)            
        table.remove(self.environments[env])            
    end

    function META:GetLocalOrEnvironmentValue(key, env, scope)
        env = env or "runtime"

        local upvalue = self:FindLocalValue(key, env, scope)
        
        if upvalue then
            return upvalue.data
        end

        local string_key = types.String(self:Hash(key)):MakeLiteral(true)

        if self.environment_nodes[1] and self.environment_nodes[1].environments_override and self.environment_nodes[1].environments_override[env] then
            return self.environment_nodes[1].environments_override[env]:Get(string_key)
        end

        if not self.environments[env][1] then
            return self.first_environment[env]:Get(string_key)
        end

        local val, err = self.environments[env][1]:Get(string_key)

        if val then
            return val
        end

        -- log error maybe?

        return  nil
    end

    function META:SetLocalOrEnvironmentValue(key, val, env, scope)
        assert(val == nil or types.IsTypeObject(val))

        if type(key) == "string" or key.kind == "value" then
            -- local key = val; key = val

            local upvalue, found_scope = self:FindLocalValue(key, env, scope)
            if upvalue then
                if not self:OnMutateUpvalue(upvalue, key, val, env) then
                    if self:GetScope():IsReadOnly() then
                        if self:GetScope() ~= found_scope then 
                            self:CreateLocalValue(key, val, env)
                            return    
                        end
                    end

                    upvalue.data = val
                end

                --self:CreateLocalValue(key, val, env)

                self:FireEvent("mutate_upvalue", key, val, env)
            else
                -- key = val

                if not self.environments[env][1] then
                    self:FatalError("tried to set environment value outside of Push/Pop/Environment")
                end

                if self:GetScope():IsReadOnly() then return end

                local ok, err = self.environments[env][1]:Set(types.String(self:Hash(key)):MakeLiteral(true), val, env == "runtime")

                self:FireEvent("set_global", key, val, env)
            end
        else
            local obj = self:AnalyzeExpression(key.left, env)

            if key.kind == "postfix_expression_index" then
                key = self:AnalyzeExpression(key.expression, env)
            elseif key.kind == "binary_operator" then
                -- this is not really correct yet
                if key.right and key.right.right then
                    key = self:AnalyzeExpression(key.right.right, env)
                else 
                    key = self:AnalyzeExpression(key.right, env)
                end
            else
                self:FatalError("unhandled function expression identifier")
            end

            self:Assert(key.node, self:NewIndexOperator(obj, key, val, env))
            self:FireEvent("newindex", obj, key, val, env)
        end
    end
end