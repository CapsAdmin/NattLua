local type = type
local ipairs = ipairs
local tostring = tostring
local LexicalScope = require("nattlua.analyzer.base.lexical_scope")
local Table = require("nattlua.types.table").Table
local LString = require("nattlua.types.string").LString
local table = require("table")
return function(META)
	table.insert(META.OnInitialize, function(self)
		self.default_environment = {
			runtime = Table(),
			typesystem = Table(),
		}
		self.environments = {runtime = {}, typesystem = {}}
		self.scope_stack = {}
	end)

	function META:Hash(node)
		if type(node) == "string" then return node end
		if type(node.value) == "string" then return node.value end
		return node.value.value
	end

	function META:PushScope(scope)
		self:FireEvent("enter_scope", scope)
		table.insert(self.scope_stack, self.scope)
		self.scope = scope
		return scope
	end

	function META:CreateAndPushFunctionScope(scope, upvalue_position)
		return self:PushScope(LexicalScope(scope or self:GetScope(), upvalue_position))
		end

		function META:CreateAndPushScope()
			return self:PushScope(LexicalScope(self:GetScope()))
			end

			function META:PopScope()
				self:FireEvent("leave_scope")
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

			function META:CloneCurrentScope()
				self:FireEvent("clone_current_scope")
				local scope_copy = self:GetScope():Copy(true)
				local g = self:GetEnvironment("runtime"):Copy()
				local last_node = self.environment_nodes[#self.environment_nodes]
			self:PopScope()
			self:PopEnvironment("runtime")
			scope_copy:SetParent(scope_copy:GetParent() or self:GetScope())
			self:PushEnvironment(last_node, g, "runtime")
			self:PushScope(scope_copy)

				for _, keyval in ipairs(g:GetData()) do
					self:FireEvent("set_environment_value", keyval.key, keyval.val)
					self:MutateValue(g, keyval.key, keyval.val)
				end

				for _, upvalue in ipairs(scope_copy:GetUpvalues("runtime")) do
					self:FireEvent("upvalue", upvalue.key, upvalue:GetValue())
					self:MutateValue(upvalue, upvalue.key, upvalue:GetValue())
				end

				return scope_copy
			end

			function META:CreateLocalValue(key, obj, function_argument)
				local upvalue = self:GetScope():CreateValue(key, obj, self:GetPreferredEnvironment())
				self:FireEvent("upvalue", key, obj, function_argument)
				self:MutateValue(upvalue, key, obj)
				return upvalue
			end

			function META:OnCreateLocalValue(upvalue, key, val) 
			end

			function META:FindLocalUpvalue(key, scope)
				if not self:GetScope() then return end

				if type(scope) == "string" then print(debug.traceback()) end
				local found, scope = (scope or self:GetScope()):FindValue(key, self:GetPreferredEnvironment())
				if found then return found, scope end
			end

			function META:FindLocalValue(key, scope)
				local upvalue = self:FindLocalUpvalue(key, scope)

				if upvalue then
					if self:IsRuntime() then return
						self:GetMutatedValue(upvalue, key, upvalue:GetValue()) or
						upvalue:GetValue() end
					return upvalue:GetValue()
				end
			end

			function META:LocalValueExists(key, scope)
				if not self:GetScope() then return end
				local found, scope = (scope or self:GetScope()):FindValue(key, self:GetPreferredEnvironment())
				return found ~= nil
			end

			function META:SetEnvironmentOverride(node, obj, env)
				node.environments_override = node.environments_override or {}
				node.environments_override[env] = obj
			end

			function META:GetEnvironmentOverride(node, env)
				if node.environments_override then return node.environments_override[env] end
			end

			function META:SetDefaultEnvironment(obj, env)
				self.default_environment[env] = obj
			end

			function META:GetDefaultEnvironment(env)
				return self.default_environment[env]
			end

			function META:PushEnvironment(node, obj, env)
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

			function META:GetEnvironment(env)
				local g = self.environments[env][1] or self:GetDefaultEnvironment(env)

				if
					self.environment_nodes[1] and
					self.environment_nodes[1].environments_override and
					self.environment_nodes[1].environments_override[env]
				then
					g = self.environment_nodes[1].environments_override[env]
				end

				return g
			end

			function META:FindEnvironmentValue(key)
				-- look up in parent if not found
				if self:IsRuntime() then
					local g = self:GetEnvironment(self:GetPreferredEnvironment())
					local val, err = g:Get(key)
					if not val then 
						self:PushPreferEnvironment("typesystem")
						local val, err = self:GetLocalOrEnvironmentValue(key)
						self:PopPreferEnvironment()
						return val, err
					end
					return self:IndexOperator(key:GetNode(), g, key)
				end

				return self:IndexOperator(key:GetNode(), self:GetEnvironment(self:GetPreferredEnvironment()), key)
			end

			function META:GetLocalOrEnvironmentValue(key, scope)
				local val = self:FindLocalValue(key, scope)
				if val then return val end
				return self:FindEnvironmentValue(key)
			end

			function META:SetLocalOrEnvironmentValue(key, val, scope)
				local upvalue, found_scope = self:FindLocalUpvalue(key, scope)

				if upvalue then
					if not self:MutateValue(upvalue, key, val) then
						upvalue:SetValue(val)
						self:FireEvent("mutate_upvalue", key, val)
					end

					return upvalue
				end

				local g = self.environments[self:GetPreferredEnvironment()][1]

				if not g then
					self:FatalError("tried to set environment value outside of Push/Pop/Environment")
				end

				if self:IsRuntime() then
					self:Warning(key:GetNode(), {"_G[\"", key:GetNode(), "\"] = ", val})
				end
				
				self:Assert(key, self:NewIndexOperator(key:GetNode(), g, key, val))

				self:FireEvent("set_environment_value", key, val)
				return val
			end
		end
