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

    function META:PushScope(scope)
        local parent = self:GetScope()

        if parent then
            scope:SetParent(parent)
        end

        if scope.node and scope.node.scope then
            scope:SetParent(scope.node.scope)
        end

        table.insert(self.scope_stack, self.scope)

        self.scope = scope

        self:FireEvent("enter_scope", scope)

        if scope.event_data and self.OnEnterScope then
            self:OnEnterScope(scope.node.kind, scope.event_data)
        end

        return scope
    end

    function META:CreateAndPushScope(node, extra_node, event_data)
        return self:PushScope(self:CreateScope(node, extra_node, event_data))
    end

    function META:CreateScope(node, extra_node, event_data)
        assert(type(node) == "table" and node.kind, "expected an associated ast node")

        return LexicalScope(node, extra_node, event_data)
    end


    function META:PopScope(event_data)
        local old = table.remove(self.scope_stack)

        self:FireEvent("leave_scope", self.scope.node, self.scope.extra_node, old)

        if old then
            self.last_scope = self.scope
            self.scope = old
        end

        if event_data and self.OnExitScope then
            self:OnExitScope(self.last_scope.node.kind, event_data)
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

    function META:CloneCurrentScope(node)
        local current_scope = self:GetScope()
        self:PopScope()
        return self:PushScope(current_scope:Copy(node))
    end

    function META:CopyUpvalue(upvalue, data)
        return {
            data = data or upvalue.data:Copy(),
            key = upvalue.key,
            shadow = upvalue.shadow,
        }
    end

    function META:CreateLocalValue(key, obj, env, function_argument)
        local upvalue = self.scope:CreateValue(key, obj, env)
        obj.upvalue = upvalue
        self:FireEvent("upvalue", key, obj, env, function_argument)
        return upvalue
    end

    function META:OnFindLocalValue(found, key, env, original_scope)
        
    end

    function META:OnCreateLocalValue(upvalue, key, val, env)
        
    end

    function META:FindLocalValue(key, env)
        if not self.scope then return end
        
        local found, scope = self.scope:FindValue(key, env)
        
        if found then
            return self:OnFindLocalValue(found, key, env, scope) or found
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

    function META:GetLocalOrEnvironmentValue(key, env)
        env = env or "runtime"

        local upvalue = self:FindLocalValue(key, env)

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

    function META:SetLocalOrEnvironmentValue(key, val, env)
        assert(val == nil or types.IsTypeObject(val))

        if type(key) == "string" or key.kind == "value" then
            -- local key = val; key = val

            local upvalue = self:FindLocalValue(key, env)
            if upvalue then

                if not self:OnMutateUpvalue(upvalue, key, val, env) then
                    upvalue.data = val
                end

                --self:CreateLocalValue(key, val, env)

                self:FireEvent("mutate_upvalue", key, val, env)
            else
                -- key = val

                if not self.environments[env][1] then
                    self:FatalError("tried to set environment value outside of Push/Pop/Environment")
                end

                local ok, err = self.environments[env][1]:Set(types.String(self:Hash(key)):MakeLiteral(true), val, env == "runtime")

                self:FireEvent("set_global", key, val, env)
            end
        else
            local obj = self:AnalyzeExpression(key.left, env)
            local key = key.kind == "postfix_expression_index" and self:AnalyzeExpression(key.expression, env) or self:AnalyzeExpression(key.right, env)

            self:Assert(key.node, self:NewIndexOperator(obj, key, val, env))
            self:FireEvent("newindex", obj, key, val, env)
        end
    end
end