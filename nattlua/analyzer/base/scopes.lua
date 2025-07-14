local type = type
local ipairs = ipairs
local tostring = tostring
local LexicalScope = require("nattlua.analyzer.base.lexical_scope").New
local Table = require("nattlua.types.table").Table
local LString = require("nattlua.types.string").LString
local table = _G.table
local table_remove = _G.table.remove
local table_insert = _G.table.insert
local type_errors = require("nattlua.types.error_messages")
return function(META)
	require("nattlua.other.context_mixin")(META)

	table_insert(META.OnInitialize, function(self)
		self.default_environment = {
			runtime = Table(),
			typesystem = Table(),
		}
		self.environments = {runtime = {}, typesystem = {}}
		self.environments_head = {runtime = {}, typesystem = {}}
		self.scope_stack = {}
		self.environment_nodes = {}
	end)

	function META:PushScope(scope)
		table_insert(self.scope_stack, self.scope)
		self.scope = scope
		return scope
	end

	local function store_scope(self, scope)
		local node = self:GetCurrentStatement()

		if node then
			node.scopes = node.scopes or {}
			table.insert(node.scopes, scope)
		end
	end

	function META:CreateAndPushFunctionScope(obj)
		local scope = LexicalScope(obj:GetScope() or self:GetScope(), obj)
		store_scope(self, scope)
		self:PushScope(scope)
		scope.upvalue_position = obj:GetUpvaluePosition() or self:IncrementUpvaluePosition()
		return scope
	end

	function META:CreateAndPushModuleScope()
		local scope = LexicalScope()
		store_scope(self, scope)
		self:PushScope(scope)
		scope.upvalue_position = self:IncrementUpvaluePosition()
		return scope
	end

	function META:CreateAndPushScope()
		local scope = LexicalScope(self:GetScope())
		store_scope(self, scope)
		self:PushScope(scope)
		scope.upvalue_position = self:IncrementUpvaluePosition()
		return scope
	end

	function META:PopScope()
		local new = table_remove(self.scope_stack)
		local old = self.scope

		if new then self.scope = new end

		return old
	end

	function META:GetScope()
		return self.scope
	end

	function META:GetScopeStack()
		return self.scope_stack
	end

	function META:IncrementUpvaluePosition()
		self.upvalue_position = (self.upvalue_position or 0) + 1
		return self.upvalue_position
	end

	function META:CreateLocalValue(key, obj, const)
		local upvalue = self:GetScope():CreateUpvalue(key, obj, self:GetCurrentAnalyzerEnvironment())
		upvalue.statement = self:GetCurrentStatement()
		upvalue:SetPosition(self:IncrementUpvaluePosition())
		self:MutateUpvalue(upvalue, obj)
		upvalue:SetImmutable(const or false)
		return upvalue
	end

	function META:FindLocalUpvalue(key, scope)
		scope = scope or self:GetScope()

		if not scope then return end

		return scope:FindUpvalue(key, self:GetCurrentAnalyzerEnvironment())
	end

	function META:GetLocalOrGlobalValue(key, scope)
		local upvalue = self:FindLocalUpvalue(key, scope)

		if upvalue then
			if self:IsRuntime() then
				return self:GetMutatedUpvalue(upvalue) or upvalue:GetValue()
			end

			return upvalue:GetValue()
		end

		-- look up in parent if not found
		if self:IsRuntime() then
			local g = self:GetGlobalEnvironment(self:GetCurrentAnalyzerEnvironment())
			local val, err = g:Get(key)

			if not val then
				self:PushAnalyzerEnvironment("typesystem")
				local val, err = self:GetLocalOrGlobalValue(key)
				self:PopAnalyzerEnvironment()
				return val, err
			end

			return self:IndexOperator(g, key)
		end

		return self:IndexOperator(self:GetGlobalEnvironment(self:GetCurrentAnalyzerEnvironment()), key)
	end

	function META:SetLocalOrGlobalValue(key, val, scope)
		local upvalue = self:FindLocalUpvalue(key, scope)

		if upvalue then
			if upvalue:IsImmutable() then
				return self:Error(type_errors.const_assignment(key))
			end

			if not self:MutateUpvalue(upvalue, val) then upvalue:SetValue(val) end

			return upvalue
		end

		local g = self:GetGlobalEnvironment(self:GetCurrentAnalyzerEnvironment())

		if not g then
			self:FatalError("tried to set environment value outside of Push/Pop/Environment")
		end

		if self:IsRuntime() then
			self:Warning(type_errors.global_assignment(key, val), self:GetCurrentStatement())
		end

		self:Assert(self:NewIndexOperator(g, key, val))
		return val
	end

	do -- environment
		do
			function META:SetEnvironmentOverride(node, obj, env)
				node.environments_override = node.environments_override or {}
				node.environments_override[env] = obj
			end

			function META:GetGlobalEnvironmentOverride(node, env)
				if node.environments_override then return node.environments_override[env] end
			end
		end

		do
			function META:SetDefaultEnvironment(obj, env)
				self.default_environment[env] = obj
			end

			function META:GetDefaultEnvironment(env)
				return self.default_environment[env]
			end
		end

		do
			function META:PushGlobalEnvironment(node, obj, env)
				node.environments = node.environments or {}
				node.environments[env] = obj
				self:PushContextValue("global_environment_" .. env, obj)
				self:PushContextValue("global_environment_nodes", node)
			end

			function META:PopGlobalEnvironment(env)
				self:PopContextValue("global_environment_" .. env)
				self:PopContextValue("global_environment_nodes")
			end

			function META:GetGlobalEnvironment(env)
				local g = self:GetContextValue("global_environment_" .. env) or
					self:GetDefaultEnvironment(env)
				local node = self:GetContextValue("global_environment_nodes")

				if node and node.environments_override and node.environments_override[env] then
					g = node.environments_override[env]
				end

				return g
			end
		end
	end
end
