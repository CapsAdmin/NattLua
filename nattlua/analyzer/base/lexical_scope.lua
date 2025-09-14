local ipairs = ipairs
local pairs = pairs
local error = error
local tostring = tostring
local assert = assert
local setmetatable = setmetatable
local Union = require("nattlua.types.union").Union
local table_insert = table.insert
local table = _G.table
local type = _G.type
local class = require("nattlua.other.class")
local Upvalue = require("nattlua.analyzer.base.upvalue").New
local META = class.CreateTemplate("lexical_scope")

do
	function META:IsUncertain()
		return self:IsTruthy() and self:IsFalsy()
	end

	function META:IsCertain()
		return not self:IsUncertain()
	end

	function META:IsCertainlyFalse()
		return self:IsFalsy() and not self:IsTruthy()
	end

	function META:IsCertainlyTrue()
		return self:IsTruthy() and not self:IsFalsy()
	end

	META:IsSet("Falsy", false--[[# as boolean]])
	META:IsSet("Truthy", false--[[# as boolean]])
end

META:IsSet("ConditionalScope", false--[[# as boolean]])
META:GetSet("Parent", nil--[[# as boolean]])
META:GetSet("Children", nil--[[# as boolean]])

function META:SetParent(parent)
	self.Parent = parent

	if parent then table_insert(parent:GetChildren(), self) end

	self:BuildParentCache()
end

function META:BuildParentCache()
	local parent = self

	for i = 1, 1000 do
		if not parent then break end

		self.ParentList[i] = parent
		self.ParentMap[parent] = parent
		parent = parent.Parent
	end

	self.Root = parent or self
end

function META:AddTrackedObject(val)
	local scope = self:GetNearestFunctionScope()
	table.insert(scope.TrackedObjects, val)
end

function META:AddDependency(val)
	self.dependencies[val] = val
end

function META:Contains(scope)
	return scope.ParentMap[self] ~= nil
end

function META:GetRoot()
	return self.Root
end

function META:GetDependencies()
	local out = {}

	if self.dependencies then
		for val in pairs(self.dependencies) do
			table.insert(out, val)
		end
	end

	return out
end

function META:FindUpvalue(key, env)
	if type(key) == "table" and key.Type == "string" and key:IsLiteral() then
		key = key:GetData()
	end

	for i, scope in ipairs(self.ParentList) do
		local upvalue = scope.upvalues[env].map[key]

		if upvalue then
			local upvalue_position = self.ParentList[i - 1] and self.ParentList[i - 1].upvalue_position

			if upvalue_position then
				if upvalue:GetPosition() >= upvalue_position then
					local upvalue = upvalue:GetShadow()

					for _ = 1, 30 do
						if not upvalue then break end

						if upvalue:GetPosition() <= upvalue_position then return upvalue end

						upvalue = upvalue:GetShadow()
					end
				end
			end

			return upvalue
		end
	end
end

local pos = 0

function META:CreateUpvalue(key, obj, env)
	local shadow

	if env == "runtime" and key ~= "..." then
		shadow = self.upvalues[env].map[key]
	end

	local upvalue = Upvalue(obj)
	upvalue:SetKey(key)
	upvalue:SetShadow(shadow or false)
	upvalue:SetScope(self)
	table_insert(self.upvalues[env].list, upvalue)
	self.upvalues[env].map[key] = upvalue
	upvalue:SetPosition(pos)
	pos = pos + 1
	return upvalue
end

function META:GetUpvalues(type--[[#: "runtime" | "typesystem"]])
	return self.upvalues[type].list
end

function META:Copy()
	local copy = self.New()

	if self.upvalues.typesystem then
		for _, upvalue in ipairs(self.upvalues.typesystem.list) do
			copy:CreateUpvalue(upvalue:GetKey(), upvalue:GetValue(), "typesystem")
		end
	end

	if self.upvalues.runtime then
		for _, upvalue in ipairs(self.upvalues.runtime.list) do
			copy:CreateUpvalue(upvalue:GetKey(), upvalue:GetValue(), "runtime")
		end
	end

	copy.returns = self.returns
	copy:SetConditionalScope(self:IsConditionalScope())
	return copy
end

META:GetSet("TrackedUpvalues", false)
META:GetSet("TrackedTables", false)

function META:FindTrackedUpvalue(upvalue)
	local upvalues = self:GetTrackedUpvalues()

	if not upvalues then return false end

	for _, data in ipairs(upvalues) do
		if data.upvalue == upvalue then return data end
	end
end

function META:TracksSameAs(scope, obj)
	local upvalues_a, tables_a = self:GetTrackedUpvalues(), self:GetTrackedTables()
	local upvalues_b, tables_b = scope:GetTrackedUpvalues(), scope:GetTrackedTables()

	if not upvalues_a or not upvalues_b then return false end

	if not tables_a or not tables_b then return false end

	for i, data_a in ipairs(upvalues_a) do
		for i, data_b in ipairs(upvalues_b) do
			if data_a.upvalue == data_b.upvalue then
				if data_a.stack and data_b.stack then
					local a = data_a.stack[#data_a.stack].truthy
					local b = data_b.stack[#data_b.stack].truthy

					if a:Equal(b) then return true end
				else
					return true
				end
			end
		end
	end

	for i, data_a in ipairs(tables_a) do
		for i, data_b in ipairs(tables_b) do
			if data_a.obj == data_b.obj and data_a.obj == obj then return true end
		end
	end

	return false
end

META:GetSet("PreviousConditionalSibling")
META:GetSet("NextConditionalSibling")
META:IsSet("ElseConditionalScope")
META:IsSet("LoopScope")

function META:SetStatement(statement)
	self.statement = statement
end

function META:SetLoopIteration(i)
	self.loop_iteration = i or false
end

function META:FindLoopIteration()
	return self:GetNearestLoopScope().loop_iteration
end

function META:GetStatementType()
	return self.statement and self.statement.Type
end

function META.BelongsToIfStatement(a, b)
	if not a.statement or not b.statement then return false end

	local yes = a:GetStatementType() == "statement_if" and
		b:GetStatementType() == "statement_if" and
		a.statement == b.statement

	if yes then
		local a_iteration = a:FindLoopIteration()
		local b_iteration = b:FindLoopIteration()
		return a_iteration == b_iteration
	end

	return yes
end

function META:FindFirstConditionalScope()
	if self.CachedConditionalScope then return self.CachedConditionalScope end

	for _, scope in ipairs(self.ParentList) do
		if scope.ConditionalScope ~= nil then
			self.CachedConditionalScope = scope
			return scope
		end
	end
end

do
	function META:MakeFunctionScope(node)
		self.returns = {}
		self.node = node
	end

	function META:IsFunctionScope()
		return self.returns ~= nil
	end

	function META:CollectOutputSignatures(node, types)
		table.insert(self:GetNearestFunctionScope().returns, {node = node, types = types})
	end

	function META:DidCertainReturn()
		return self.certain_return ~= false
	end

	function META:ClearCertainReturn()
		self.certain_return = false
	end

	function META:CertainReturn()
		for _, scope in ipairs(self.ParentList) do
			scope.certain_return = true

			if scope.returns then break end
		end
	end

	function META:UncertainReturn()
		self:GetNearestFunctionScope().uncertain_function_return = true
	end

	function META:DidUncertainReturn()
		return self:GetNearestFunctionScope().uncertain_function_return == true
	end

	function META:GetNearestFunctionScope()
		if self.CachedFunctionScope then return self.CachedFunctionScope end

		for _, scope in ipairs(self.ParentList) do
			if scope.returns then
				self.CachedFunctionScope = scope
				return scope
			end
		end

		self.CachedFunctionScope = self
		return self
	end

	function META:GetNearestLoopScope()
		if self.CachedLoopScope then return self.CachedLoopScope end

		for _, scope in ipairs(self.ParentList) do
			if scope.LoopScope then
				self.CachedLoopScope = scope
				return scope
			end
		end

		self.CachedLoopScope = self
		return self
	end

	function META:GetOutputSignature()
		return self.returns
	end

	function META:ClearCertainOutputSignatures()
		self.returns = {}
	end

	function META:IsCertainFromScope(from)
		return not self:IsUncertainFromScope(from)
	end

	function META:IsUncertainFromScope(from)
		if from == self then return false end

		if self:BelongsToIfStatement(from) then return true end

		if self:Contains(from) then return false end

		for _, scope in ipairs(self.ParentList) do
			if scope == from then break end

			if scope:IsFunctionScope() then
				if
					scope.node and
					scope.node:GetLastAssociatedType() and
					scope.node:GetLastAssociatedType().Type == "function" and
					not scope:Contains(from)
				then
					return not scope.node:GetLastAssociatedType():IsCalled()
				end
			end

			if scope:IsTruthy() and scope:IsFalsy() then
				if scope:Contains(from) then return false end

				return true, scope
			end
		end

		return false
	end
end

function META:__tostring()
	local x = #self.ParentList
	local y = 1

	if self:GetParent() then
		for i, v in ipairs(self:GetParent():GetChildren()) do
			if v == self then
				y = i

				break
			end
		end
	end

	local s = "scope[" .. x .. "," .. y .. "]" .. "[" .. (
			self:IsUncertain() and
			"uncertain" or
			"certain"
		) .. "]"

	if self.node then s = s .. tostring(self.node) end

	return s
end

function META:DumpScope()
	local s = {}

	for i, v in ipairs(self.upvalues.runtime.list) do
		table.insert(s, "local " .. tostring(v:GetKey()) .. " = " .. tostring(v:GetValue()))
	end

	for i, v in ipairs(self.upvalues.typesystem.list) do
		table.insert(s, "local type " .. tostring(v:GetKey()) .. " = " .. tostring(v:GetValue()))
	end

	for i, v in ipairs(self:GetChildren()) do
		table.insert(s, "do\n" .. v:DumpScope() .. "\nend\n")
	end

	return table.concat(s, "\n")
end

function META:FindUnusedUpvalues(unused)
	unused = unused or {}

	for _, upvalue in ipairs(self.upvalues.runtime.list) do
		if upvalue:GetUseCount() == 0 and upvalue:GetKey() ~= "..." then
			table.insert(unused, upvalue)
		end
	end

	for _, upvalue in ipairs(self.upvalues.typesystem.list) do
		if upvalue:GetUseCount() == 0 and upvalue:GetKey() ~= "..." then
			table.insert(unused, upvalue)
		end
	end

	for _, child in ipairs(self:GetChildren()) do
		child:FindUnusedUpvalues(unused)
	end

	return unused
end

function META:GetAllVisibleUpvalues()
	local upvalues = {}

	for _, scope in ipairs(self.ParentList) do
		for _, upvalue in ipairs(scope.upvalues.runtime.list) do
			if not upvalues[upvalue:GetKey()] then
				upvalues[upvalue:GetKey()] = upvalue
			end
		end

		for _, upvalue in ipairs(scope.upvalues.typesystem.list) do
			if not upvalues[upvalue:GetKey()] then
				upvalues[upvalue:GetKey()] = upvalue
			end
		end
	end

	return upvalues
end

function META.New(parent, upvalue_position, obj)
	local scope = META.NewObject(
		{
			obj = obj,
			CachedLoopScope = false,
			CachedFunctionScope = false,
			Children = {},
			upvalue_position = upvalue_position or pos,
			uncertain_function_return = false,
			TrackedObjects = {},
			loop_iteration = false,
			returns = false,
			statement = false,
			node = false,
			scope_helper = false,
			missing_return = false,
			missing_types = false,
			lua_silent_error = false,
			certain_return = false,
			mutated_types = {},
			ParentList = {},
			ParentMap = {},
			Root = false,
			dependencies = {},
			throws = false,
			ElseConditionalScope = false,
			ConditionalScope = false,
			TrackedUpvalues = false,
			TrackedTables = false,
			Truthy = false,
			Falsy = false,
			Parent = false,
			LoopScope = false,
			NextConditionalSibling = false,
			PreviousConditionalSibling = false,
			upvalues = {
				runtime = {
					list = {},
					map = {},
				},
				typesystem = {
					list = {},
					map = {},
				},
			},
		}
	)
	scope:SetParent(parent or false)
	pos = pos + 1
	return scope
end

return META
