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

function META.GetSet(tbl--[[#: ref any]], name--[[#: ref string]], default--[[#: ref any]])
	tbl[name] = default--[[# as NonLiteral<|default|>]]
--[[#	type tbl.@Self[name] = tbl[name] ]]
	tbl["Set" .. name] = function(self--[[#: tbl.@Self]], val--[[#: tbl[name] ]])
		self[name] = val
		return self
	end
	tbl["Get" .. name] = function(self--[[#: tbl.@Self]])--[[#: tbl[name] ]]
		return self[name]
	end
end

function META.IsSet(tbl--[[#: ref any]], name--[[#: ref string]], default--[[#: ref any]])
	tbl[name] = default--[[# as NonLiteral<|default|>]]
--[[#	type tbl.@Self[name] = tbl[name] ]]
	tbl["Set" .. name] = function(self--[[#: tbl.@Self]], val--[[#: tbl[name] ]])
		self[name] = val
		return self
	end
	tbl["Is" .. name] = function(self--[[#: tbl.@Self]])--[[#: tbl[name] ]]
		return self[name]
	end
end

do
	function META:IsUncertain()
		return self:IsTruthy() and self:IsFalsy()
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

META:IsSet("TestScope", false--[[# as boolean]])


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
	copy:SetTestScope(self:IsTestScope())
	
	return copy
end

function META:GetParent()
	return self.parent
end

function META:SetTrackedObjects(upvalues, tables)
	self.tracked_upvalues = upvalues
	self.tracked_tables = tables
end


function META:TracksSameAs(scope)
	local upvalues_a, tables_a = self:GetTrackedObjects()
	local upvalues_b, tables_b = scope:GetTrackedObjects()

	if not upvalues_a or not upvalues_b then return false end
	if not tables_a or not tables_b then return false end

	for i, data_a in ipairs(upvalues_a) do
		for i, data_b in ipairs(upvalues_b) do
			if data_a.upvalue == data_b.upvalue then
				return true
			end
		end
	end

	for i, data_a in ipairs(tables_a) do
		for i, data_b in ipairs(tables_b) do
			if data_a.obj == data_b.obj then
				return true
			end
		end
	end

	return false
end

function META:FindResponsibleTestScopeFromUpvalue(upvalue)
	local scope = self

	while true do
		local upvalues = scope:GetTrackedObjects()
		if upvalues then
			for i, data in ipairs(upvalues) do
				if data.upvalue == upvalue then
					return scope, data
				end
			end
		end
        
        -- find in siblings too, if they have returned
        -- ideally when cloning a scope, the new scope should be 
        -- inside of the returned scope, then we wouldn't need this code
        
        for _, child in ipairs(scope:GetChildren()) do
			if child ~= scope and self:IsPartOfTestStatementAs(child) then
				local upvalues = child:GetTrackedObjects()
				if upvalues then
					for i, data in ipairs(upvalues) do
						if data.upvalue == upvalue then
							return child, data
						end
					end
				end
			end
		end

		scope = scope:GetParent()
		if not scope then return end
	end

	return nil
end

function META:GetTrackedObjects()
	return self.tracked_upvalues, self.tracked_tables
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
	local obj, scope = self:GetMemberInParents("TestScope")
	return scope
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

	function META:UncertainReturn()
		self:GetNearestFunctionScope().uncertain_function_return = true
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

	function META:IsCertainFromScope(from)
		return not self:IsUncertainFromScope(from)
	end

	function META:IsUncertainFromScope(from)
		if from == self then return false end
		local scope = self
		
		if not from then
			return self:IsTruthy() and self:IsFalsy()
		end

		if self:IsPartOfTestStatementAs(from) then return true end

		while true do
			if scope == from then break end
			if scope:IsFunctionScope() then 
				if 
					scope.node and 
					scope.node.inferred_type and 
					scope.node.inferred_type.Type == "function" and 
					not scope:Contains(from)
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
			if scope:IsTruthy() and scope:IsFalsy() then
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

	local s = "scope[" .. x .. "," .. y .. "]" .. "[" .. (self:IsUncertain() and "uncertain" or "certain") .. "]" 

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
