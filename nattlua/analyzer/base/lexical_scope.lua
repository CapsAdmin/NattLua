local ipairs = ipairs
local pairs = pairs
local error = error
local tostring = tostring
local assert = assert
local setmetatable = setmetatable
local Union = require("nattlua.types.union").Union
local table_insert = table.insert
local table = require("table")
local type = _G.type
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

	function META:GetNode()
		return self.node
	end

	function META:GetKey()
		return self.key
	end

	function META:SetValue(value)
		self.value = value
		value:SetUpvalue(self)
	end

	upvalue_meta = META
end

local META = {}
META.__index = META
local LexicalScope

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

function META:GetChildren()
	return self.children
end

function META:Hash(node)
	if type(node) == "table" and node.Type == "string" and node:IsLiteral() then return node:GetData() end
	if type(node) == "string" then return node end
	if type(node.value) == "string" then return node.value end
	return node.value.value
end

function META:GetMemberInParents(what)
	local scope = self

	while true do
		if scope[what] then return scope[what], scope end
		scope = scope.parent
		if not scope then break end
	end

	return nil
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
	local prev_scope

	for _ = 1, 1000 do
		if not scope then return end
		local upvalue = scope.upvalues[env].map[key_hash]

		if upvalue then
			local upvalue_position = prev_scope and prev_scope.upvalue_position

			if upvalue_position then
				if upvalue.position >= upvalue_position then
					local upvalue = upvalue.shadow

					while upvalue do
						if upvalue.position <= upvalue_position then return upvalue end
						upvalue = upvalue.shadow
					end
				end
			end

			return upvalue, scope
		end

		prev_scope = scope
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

function META:CreateValue(key, obj, env)
	local key_hash = self:Hash(key)
	assert(key_hash)
	assert(obj)
	assert(type(env) == "string")
	local shadow

	if key_hash ~= "..." and env == "runtime" then
		shadow = self.upvalues[env].map[key_hash]
	end

	local upvalue = {
			key = key_hash,
			node = key,
			shadow = shadow,
			position = #self.upvalues[env].list,
		}
	setmetatable(upvalue, upvalue_meta)
	table_insert(self.upvalues[env].list, upvalue)
	self.upvalues[env].map[key_hash] = upvalue
	upvalue:SetValue(obj)
	upvalue.scope = self
	return upvalue
end

function META:GetUpvalues(type--[[#: "runtime" | "typesystem"]])
	return self.upvalues[type].list
end

function META:Copy()
	local copy = LexicalScope()

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

	copy.returns = self.returns
	copy.parent = self.parent
	
	return copy
end

function META:GetParent()
	return self.parent
end

function META:SetTestCondition(obj)
	self.test_condition = obj
end

function META:SetAffectedUpvaluesMap(upvalues)
	self.upvalue_map = upvalues
end


function META:GetAffectedUpvaluesMap()
	return self.upvalue_map
end

function META:SetStatement(statement)
	self.statement = statement
end

function META:GetStatementType()
	return self.statement and self.statement.kind
end

function META:InvertIfStatement(b)
	self.is_else = b
end

function META:IsPartOfElseStatement()
	return self.is_else == true
end

function META.IsPartOfTestStatementAs(a, b)
	return
		a:GetStatementType() == "if" and
		b:GetStatementType() == "if" and
		a.statement == b.statement
end

function META:FindFirstTestScope()
	local obj, scope = self:GetMemberInParents("test_condition")
	return scope
end

function META:GetTestCondition()
	return self.test_condition
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
	function META:MakeFunctionScope(node)
		self.returns = {}
		self.node = node
	end

	function META:IsFunctionScope()
		return self.returns ~= nil
	end

	function META:CollectReturnTypes(node, types)
		table.insert(self:GetNearestFunctionScope().returns, {node = node, types = types})
	end

	function META:DidCertainReturn()
		return self.certain_return ~= nil
	end

	function META:ClearCertainReturn()
		self.certain_return = nil
	end


	function META:CertainReturn()
		local scope = self

		while true do
			scope.certain_return = true
			if scope.returns then break end
			scope = scope.parent
			if not scope then break end
		end
	end

	function META:UncertainReturn(analyzer)

		self:GetNearestFunctionScope().uncertain_function_return = true

		local upvalue_map = self:GetAffectedUpvaluesMap()

		-- the or part here refers to if *condition* then
		-- truthy/falsy _union is only created from binary operators and some others
		if not upvalue_map then return end
		for upvalue, stack in pairs(upvalue_map) do
			if upvalue.Type == "upvalue" then
				local val
				if self:IsPartOfElseStatement() or stack[#stack].inverted then
					val = stack[#stack].truthy
				else	
					val = stack[#stack].falsy
				end

				if val and (val.Type ~= "union" or not val:IsEmpty()) then
					analyzer:MutateUpvalue(
						upvalue,
						val,
						self:GetParent()
					)
				end
			end
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

	function META:ClearCertainReturnTypes()
		self.returns = {}
	end

	function META:IsCertain(from)
		return not self:IsUncertain(from)
	end

	function META:IsUncertain(from)
		if from == self then return false end
		local scope = self
		
		if not from then
			return self.uncertain
		end

		if self:IsPartOfTestStatementAs(from) then return true end

		while true do
			if scope == from then break end
			if scope:IsFunctionScope() then 
				if 
					scope.node and 
					scope.node.inferred_type and 
					scope.node.inferred_type.Type == "function" 
				then
					return not scope.node.inferred_type:IsCalled() 
				end

				if scope.uncertain_function_return == false then
					return false
				end

				if not scope:Contains(from) then
					return true
				end
			end 
			if scope.uncertain then
				if scope:Contains(from) then
					return false
				end
				return true, scope 
			end
			scope = scope.parent
			if not scope then break end
		end

		return false
	end

	function META:MakeUncertain(b)
		self.uncertain = b
	end

	function META:SetCanThrow(b)
		self.can_throw = b
	end

	function META:CanThrow()
		return self.can_throw == true
	end
end

function META:__tostring()
	local x = 1

	do
		local scope = self

		while scope.parent do
			x = x + 1
			scope = scope.parent
		end
	end

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
		table.insert(s, "local " .. tostring(v.key) .. " = " .. tostring(v))
	end


	for i, v in ipairs(self.upvalues.typesystem.list) do
		table.insert(s, "local type " .. tostring(v.key) .. " = " .. tostring(v))
	end

	for i, v in ipairs(self.children) do
		table.insert(s, "do\n" .. v:DumpScope() .. "\nend\n")
	end

	return table.concat(s, "\n")
end

local ref = 0

function LexicalScope(parent, upvalue_position)
	ref = ref + 1
	local scope = {
			ref = ref,
			children = {},
			upvalue_position = upvalue_position,
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
