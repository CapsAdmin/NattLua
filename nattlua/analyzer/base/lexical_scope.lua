local ipairs = ipairs
local pairs = pairs
local error = error
local tostring = tostring
local assert = assert
local setmetatable = setmetatable
local types = require("nattlua.types.types")
local type = _G.type
local table_insert = table.insert
local table = require("table")
local type = _G.type
local META = {}
META.__index = META
local LexicalScope

function META:Initialize() 
end

function META:SetParent(parent)
	self.parent = parent

	if parent then
		parent:AddChild(self)
	end
end

function META:AddChild(scope)
	scope.parent = self
	table_insert(self.children, scope)
end

function META:Unparent()
	if self.parent then
		for i, v in ipairs(self.parent:GetChildren()) do
			if v == self then
				table.remove(i, self.parent:GetChildren())

				break
			end
		end
	end

	self.parent = nil
end

function META:GetChildren()
	return self.children
end

function META:Hash(node)
	if type(node) == "string" then return node end
	if type(node.value) == "string" then return node.value end
	return node.value.value
end

function META:MakeReadOnly(b)
	self.read_only = b
end

function META:GetParents()
	local list = {}
	local scope = self

	while true do
		table.insert(list, scope)
		scope = scope.parent
		if not scope then break end
	end

	return list
end

function META:GetMemberInParents(what)
	for _, scope in ipairs(self:GetParents()) do
		if scope[what] then return scope[what], scope end
	end

	return nil
end

function META:IsReadOnly()
	return self:GetMemberInParents("read_only")
end

function META:GetIterationScope()
	local boolean, scope = self:GetMemberInParents("is_iteration_scope")
	return scope
end

function META:AddDependency(val)
	self.dependencies = self.dependencies or {}
	self.dependencies[val] = val
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

function META:FindValue(key, env)
	local key_hash = self:Hash(key)
	local scope = self

	for _ = 1, 1000 do
		if not scope then return end
		if scope.upvalues[env].map[key_hash] then return scope.upvalues[env].map[key_hash] end
		scope = scope.parent
	end

	error("this should never happen")
end

function META:FindScopeFromObject(obj, env)
	local scope = self

	for i = 1, 1000 do
		if not scope then return end

		for i, v in ipairs(scope.upvalues[env].list) do
			if obj == v:GetValue() then return scope end
		end

		scope = scope.parent
	end

	error("this should never happen")
end

local upvalue_meta

do
	local META = {}
	META.__index = META
	META.Type = "upvalue"

	function META:__tostring()
		return "[" .. self.key .. ":" .. tostring(self.value) .. "]"
	end

	function META:GetValue()
		return self.value
	end

	function META:SetValue(value)
		self.value = value
		value:SetUpvalue(self)
	end

	upvalue_meta = META
end

function META:CreateValue(key, obj, env)
	local key_hash = self:Hash(key)
	assert(key_hash)
	local upvalue = {
		key = key_hash,
		shadow = self:FindValue(key, env),
	}
	setmetatable(upvalue, upvalue_meta)
	table_insert(self.upvalues[env].list, upvalue)
	self.upvalues[env].map[key_hash] = upvalue
	upvalue:SetValue(obj)
	upvalue.scope = self
	return upvalue
end

function META:Copy(upvalues)
	local copy = LexicalScope()

	if upvalues then
		if self.upvalues.typesystem then
			for _, upvalue in ipairs(self.upvalues.typesystem.list) do
				copy:CreateValue(upvalue.key, upvalue:GetValue(), "typesystem")
			end
		end

		if self.upvalues.runtime then
			for _, upvalue in ipairs(self.upvalues.runtime.list) do
				copy:CreateValue(upvalue.key, upvalue:GetValue(), "runtime")
			end
		end
	end

	copy.returns = self.returns
	return copy
end

function META:Merge(scope)
	for i, a in ipairs(self.upvalues.runtime.list) do
		local b = scope.upvalues.runtime.list[i]

		if a and b and a.key == b.key then
			a:SetValue(types.Union({a:GetValue(), b:GetValue()}))
			a:GetValue():SetNode(b:GetValue():GetNode())
			a:GetValue():SetTokenLabelSource(b:GetValue():GetTokenLabelSource()) 
			self.upvalues.runtime.map[a.key]:GetValue(a:GetValue())
		end
	end
end

function META:HasParent(scope)
	for _, parent in ipairs(self:GetParents()) do
		if parent == scope then return true end
	end

	return false
end

function META:SetTestCondition(obj, inverted)
	self.test_condition = obj
	self.test_condition_inverted = inverted
end

function META:GetTestCondition()
	local obj, scope = self:GetMemberInParents("test_condition")
	return obj, scope and scope.test_condition_inverted or nil
end

function META:Contains(scope)
	if scope == self then return true end
	local parent = scope

	for i = 1, 1000 do
		if not parent then break end
		if parent == self then return true end
		parent = parent.parent
	end

	return false
end

function META:GetRoot()
	local parent = self

	for i = 1, 1000 do
		if not parent.parent then break end
		parent = parent.parent
	end

	return parent
end

do
	function META:MakeFunctionScope()
		self.returns = {}
	end

	function META:CollectReturnTypes(node, types)
		table.insert(self:GetNearestFunctionScope().returns, {node = node, types = types})
	end

	function META:DidReturn()
		return self.returned ~= nil
	end

	function META:ClearReturn()
		self.returned = nil
	end

	function META:Return(uncertain)
		local scope = self

		while true do
			if uncertain then
				scope.uncertain_returned = true
				scope.test_condition_inverted = not scope.test_condition_inverted
			else
				scope.returned = true
			end

			if scope.returns then break end
			scope = scope.parent
			if not scope then break end
		end
	end

	function META:GetNearestFunctionScope()
		local ok, scope = self:GetMemberInParents("returns")
		if ok then return scope end
		error("cannot find a scope to return to", 2)
	end

	function META:GetReturnTypes()
		return self.returns
	end

	function META:ClearReturnTypes()
		self.returns = {}
	end

	function META:IsCertain(from)
		return not self:IsUncertain(from)
	end

	function META:IsUncertain(from)
		if from == self then return false end

		for _, scope in ipairs(self:GetParents()) do
			if scope == from then break end
			if scope.uncertain then return true, scope end
		end

		return false
	end

	function META:MakeUncertain(b)
		self.uncertain = b
	end
end

local ref = 0

function META:__tostring()
	local x = #self:GetParents()
	local y = 1

	if self.parent then
		for i, v in ipairs(self.parent:GetChildren()) do
			if v == self then
				y = i

				break
			end
		end
	end

	local s = "scope[" .. x .. "," .. y .. "]" .. "[" .. (self:IsUncertain() and "uncertain" or "certain") .. "]" .. "[" .. tostring(self:GetTestCondition() or nil) .. "]"

	if self.returns then
		s = s .. "[function scope]"
	end

	return s
end

function META:DumpScope()
	local s = {}

	for i, v in ipairs(self.upvalues.runtime.list) do
		table.insert(s, "local " .. tostring(v.key) .. " = " .. tostring(v:GetData()))
	end

	for i, v in ipairs(self.children) do
		table.insert(s, "do\n" .. v:DumpScope() .. "\nend\n")
	end

	return table.concat(s, "\n")
end

function LexicalScope(parent)
	ref = ref + 1
	local scope = {
			ref = ref,
			children = {},
			upvalues = {
				runtime = {list = {}, map = {},},
				typesystem = {list = {}, map = {},},
			},
		}
	setmetatable(scope, META)
	scope:SetParent(parent)
	return scope
end

return LexicalScope
