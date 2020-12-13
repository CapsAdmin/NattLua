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
        table.insert(self.scope_stack, self.scope)

        self.scope = scope

        return scope
    end

    function META:CreateAndPushFunctionScope(node)
        return self:PushScope(LexicalScope(node and node.function_scope or self:GetScope()))
    end

    function META:CreateAndPushScope()
        return self:PushScope(LexicalScope(self:GetScope()))
    end

    function META:PopScope()
        local old = table.remove(self.scope_stack)

        if old then
            self.last_scope = self:GetScope()
            self.scope = old
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

    function META:CloneCurrentScope(upvalues)
        local current_scope = self:GetScope()
        self:PopScope()
        local scope = current_scope:Copy(upvalues)
        
        local parent = self:GetScope()

        if parent then
            scope:SetParent(parent)
        end

        return self:PushScope(scope)
    end

    function META:CreateLocalValue(key, obj, env, function_argument)
        local upvalue = self:GetScope():CreateValue(key, obj, env)
        self:FireEvent("upvalue", key, obj, env, function_argument)
        return upvalue
    end

    function META:OnFindLocalValue(found, key, env, value, original_scope)
        
    end

    function META:OnCreateLocalValue(upvalue, key, val, env)
        
    end

    function META:FindLocalUpvalue(key, env, scope)
        if not self:GetScope() then return end
                
        local found, scope = (scope or self:GetScope()):FindValue(key, env)
        
        if found then
            return found, scope
        end
    end

    function META:FindLocalValue(key, env, scope)
        local upvalue = self:FindLocalUpvalue(key, env, scope)
        if upvalue then
            local t = self:OnFindLocalValue(upvalue, key, upvalue:GetValue(), env, scope)
            return t or upvalue:GetValue()
        end 
    end

    function META:LocalValueExists(key, env, scope)
        if not self:GetScope() then return end
                
        local found, scope = (scope or self:GetScope()):FindValue(key, env)
        
        return found ~= nil
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

        local val = self:FindLocalValue(key, env, scope)
        
        if val then
            return val
        end

        local string_key = key
        local g = self.environments[env][1] or self.first_environment[env]

        if self.environment_nodes[1] and self.environment_nodes[1].environments_override and self.environment_nodes[1].environments_override[env] then
            g = self.environment_nodes[1].environments_override[env]
        end
        
        return g:Get(key)
    end

    function META:SetLocalOrEnvironmentValue(key, val, env, scope)
        local upvalue, found_scope = self:FindLocalUpvalue(key, env, scope)
        
        if upvalue then
            if not self:OnMutateUpvalue(upvalue, key, val, env) then
                if self:GetScope():IsReadOnly() then
                    if self:GetScope() ~= found_scope then 
                        
                        self:CreateLocalValue(key, val, env)

                        return    
                    end
                end

                upvalue:SetValue(val)
                self:FireEvent("mutate_upvalue", key, val, env)
            end
        else
            local g = self.environments[env][1]

            if not g then
                self:FatalError("tried to set environment value outside of Push/Pop/Environment")
            end

            if self:GetScope():IsReadOnly() then return end

            if not self:OnMutateEnvironment(g, key, val, env) then 
                self:Assert(key, g:Set(key, val, env == "runtime"))
            end

            self:FireEvent("set_environment_value", key, val, env)
        end
    end
end