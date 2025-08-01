--ANALYZE
local tostring = tostring
local setmetatable = _G.setmetatable
local table = _G.table
local type = _G.type
local ipairs = _G.ipairs
local Nil = require("nattlua.types.symbol").Nil
local True = require("nattlua.types.symbol").True
local False = require("nattlua.types.symbol").False
local type_errors = require("nattlua.types.error_messages")
local table_concat = _G.table.concat
local table_remove = _G.table.remove
local table_sort = require("nattlua.other.sort")
local table_clear = require("nattlua.other.tablex").clear

--[[#local type { TNumber } = require("nattlua.types.number")]]

local META = dofile("nattlua/types/base.lua")
--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TUnion"]]
--[[#type TUnion = META.@Self]]
--[[#type TUnion.Data = List<|TBaseType|>]]
--[[#type TUnion.Hash = nil | string]]
--[[#type TUnion.LiteralDataCache = Map<|string, TBaseType|>]]
--[[#type TUnion.suppress = boolean]]
--[[#type TUnion.left_right_source = {left = TBaseType, right = TBaseType} | false]]
--[[#type TUnion.parent_table = {table = TBaseType, key = string} | false]]
META.Type = "union"

function META:GetHashForMutationTracking()
	return tostring(self)
end

function META.Equal(
	a--[[#: TUnion]],
	b--[[#: TBaseType]],
	visited--[[#: nil | Map<|TBaseType, boolean|>]]
)
	visited = visited or {}

	if visited[a] then return true, "circular reference detected" end

	if b.Type ~= "union" and a:GetCardinality() == 1 and a.Data[1] then
		return a.Data[1]:Equal(b, visited)
	end

	if a.Type ~= b.Type then return false, "types differ" end

	local b = b
	local len = #a.Data

	if len ~= #b.Data then return false, "length mismatch" end

	for i = 1, len do
		local a = a.Data[i]
		local ok = false

		if a.Type == "table" then visited[a] = true end

		local reasons = {}

		for i = 1, len do
			local b = b.Data[i]
			local reason
			ok, reason = a:Equal(b, visited)

			if ok then break end

			table.insert(reasons, reason)
		end

		if not ok then
			return false, "union value mismatch: " .. table.concat(reasons, "\n")
		end
	end

	return true, "all union values match"
end

function META:GetHash(visited)--[[#: string]]
	if self:GetCardinality() == 1 then
		return (self.Data[1]--[[# as any]]):GetHash()
	end

	visited = visited or {}

	if visited[self] then return visited[self] end

	visited[self] = "*circular*"
	local types = {}

	for i, v in ipairs(self.Data) do
		types[i] = v:GetHash(visited)
	end

	table.sort(types)
	visited[self] = table.concat(types, "|")
	return visited[self]
end

local sort = function(a--[[#: string]], b--[[#: string]])
	return a < b
end

function META:__tostring()
	if self.suppress then return "current_union" end

	local s = {}
	self.suppress = true

	for i, v in ipairs(self.Data) do
		s[i] = tostring(v)
	end

	if not s[1] then
		self.suppress = false
		return "|"
	end

	self.suppress = false

	if #s == 1 then return (s[1]--[[# as string]]) .. "|" end

	table_sort(s, sort)
	return table_concat(s, " | ")
end

local ANY_TYPE = {}
local STRING_TYPE = {}
local NUMBER_TYPE = {}

local function hash(obj)
	if obj.Type ~= "table" and obj.Type ~= "function" and obj.Type ~= "tuple" then
		return obj:GetHash()
	end
end

local function add(self--[[#: TUnion]], obj--[[#: any]])
	local s = hash(obj)

	if s then self.LiteralDataCache[s] = obj end

	self.Data[#self.Data + 1] = obj
end

local function remove(self--[[#: TUnion]], index--[[#: number]])
	local obj = assert(self.Data[index])
	table_remove(self.Data, index)
	local s = hash(obj)

	if s then self.LiteralDataCache[s] = nil end
end

local function find_index(self--[[#: TUnion]], obj--[[#: any]])
	for i = 1, #self.Data do
		local v = self.Data[i]--[[# as any]]

		if v:Equal(obj) then
			if v.Type ~= "function" or v:GetFunctionBodyNode() == obj:GetFunctionBodyNode() then
				return i
			end
		end
	end

	return nil
end

function META:AddType(e--[[#: TBaseType]])
	if e.Type == "union" then
		for _, v in ipairs(e.Data) do
			self:AddType(v)
		end

		return self
	end

	do
		local s = hash(e)

		if s and self.LiteralDataCache[s] then return self end
	end

	if find_index(self, e) then return self end

	add(self, e)
	return self
end

function META:GetData()
	return self.Data
end

function META:GetCardinality()
	return #self.Data
end

function META:RemoveType(e--[[#: TBaseType]])
	if e.Type == "union" then
		for i, v in ipairs(e.Data) do
			self:RemoveType(v)
		end

		return self
	end

	local index = find_index(self, e)

	if index then remove(self, index) end

	return self
end

function META:Clear()
	do
		(table_clear--[[# as any]])(self.Data)
	end

	do
		(table_clear--[[# as any]])(self.LiteralDataCache)
	end
end

function META:HasTuples()
	for _, obj in ipairs(self.Data) do
		if obj.Type == "tuple" then return true end
	end

	return false
end

function META:GetTupleLength()
	local len = 0

	for _, obj in ipairs(self.Data) do
		if obj.Type == "union" or obj.Type == "tuple" then
			len = math.max(len, obj:GetTupleLength())
		else
			len = math.max(len, 1)
		end
	end

	return len
end

function META:GetAtTupleIndex(i)
	if i > self:GetTupleLength() then return nil end

	local obj = self:GetAtTupleIndexUnion(i)--[[# as any]]

	if obj then
		if obj.Type == "union" then
			return obj:GetAtTupleIndexUnion(i)
		elseif obj.Type == "tuple" then
			return obj:GetWithNumber(i)
		end
	end

	return obj
end

function META:GetAtTupleIndexUnion(i--[[#: number]])
	if not self:HasTuples() then return self:Simplify() end

	local val--[[#: any]]
	local errors = {}
	local is_inf = false

	for _, obj in ipairs(self.Data) do
		if obj.Type == "tuple" then
			local found, err = (obj--[[# as any]]):GetWithNumber(i)

			if found then
				if (obj--[[# as any]]):GetElementCount() == math.huge then is_inf = true end

				if found.Type == "union" then
					found, err = found:GetAtTupleIndexUnion(1)
				elseif found.Type == "tuple" then
					found, err = found:GetAtTupleIndex(1)
				end
			end

			if found then
				if val then val = self.New({val, found}) else val = found end
			else
				if val then val = self.New({val, Nil()}) else val = Nil() end
			end
		elseif i == 1 then
			if val then val = self.New({val, obj}) else val = obj end
		else
			if val then val = self.New({val, Nil()}) else val = Nil() end
		end
	end

	if
		(
			val.Type == "symbol" or
			val.Type == "union" and
			val:GetCardinality() == 1
		)
		and
		val:IsNil()
	then
		return nil
	end

	if not val then return false, errors end

	if val.Type == "union" and val:GetCardinality() == 1 then return val.Data[1] end

	return val, is_inf
end

function META:IsTypeObjectSubsetOf(typ--[[#: TBaseType]])
	local errors

	for i, obj in ipairs(self.Data) do
		local ok, reason = typ:IsSubsetOf(obj)

		if ok then return obj end

		errors = errors or {}
		errors[i] = reason
	end

	return false, errors
end

function META:HasTypeObject(obj--[[#: TBaseType]])
	for i, v in ipairs(self.Data) do
		local ok, reason = obj:IsSubsetOf(v)

		if ok then return v end
	end

	return false
end

function META:IsEmpty()
	return self.Data[1] == nil
end

function META:RemoveCertainlyFalsy()
	local copy = META.New()

	for _, obj in ipairs(self.Data) do
		if not obj:IsCertainlyFalse() then add(copy, obj) end
	end

	return copy:Simplify()
end

function META:GetTruthy()
	local copy = META.New()

	for _, obj in ipairs(self.Data) do
		if obj:IsTruthy() then add(copy, obj) end
	end

	return copy
end

function META:GetFalsy()
	local copy = META.New()

	for _, obj in ipairs(self.Data) do
		if obj:IsFalsy() then add(copy, obj) end
	end

	return copy
end

function META:IsType(typ--[[#: string]])
	if self:IsEmpty() then return false end

	for _, obj in ipairs(self.Data) do
		if obj.Type ~= typ then return false end
	end

	return true
end

function META:IsTypeExceptNil(typ--[[#: string]])
	if self:IsEmpty() then return false end

	for _, obj in ipairs(self.Data) do
		if obj.Type == "symbol" and obj:IsNil() then

		else
			if obj.Type ~= typ then return false end
		end
	end

	return true
end

function META:HasType(typ--[[#: string]])
	return self:GetType(typ) ~= false
end

function META:IsNil()
	for _, obj in ipairs(self.Data) do
		if obj.Type == "symbol" and obj:IsNil() then return true end
	end

	return false
end

function META:GetType(typ--[[#: string]])
	for _, obj in ipairs(self.Data) do
		if obj.Type == typ then return obj end
	end

	return false
end

function META:IsTargetSubsetOfChild(target--[[#: TBaseType]])
	local errors = {}

	for i, obj in ipairs(self.Data) do
		local ok, reason = target:IsSubsetOf(obj)

		if ok then return true end

		errors[i] = reason
	end

	return false, type_errors.subset(target, self, errors)
end

function META.IsSubsetOf(a--[[#: TUnion]], b--[[#: any]])
	if a.suppress then return true, "suppressed" end

	if b.Type == "tuple" then b = b:GetWithNumber(1) end

	if b.Type == "any" then return true end

	if a:IsEmpty() then
		return false, type_errors.because(type_errors.subset(a, b), "union is empty")
	end

	for _, a_val in ipairs(a.Data) do
		a.suppress = true
		local b_val, reason

		if b.Type == "union" then
			b_val, reason = b:IsTypeObjectSubsetOf(a_val)
		else
			local ok, reason = a_val:IsSubsetOf(b)

			if ok then
				b_val = b
			else
				b_val = false
				reason = reason
			end
		end

		a.suppress = false

		if not b_val then
			return false, type_errors.because(type_errors.subset(b, a_val), reason)
		end

		a.suppress = true
		local ok, reason = a_val:IsSubsetOf(b_val)
		a.suppress = false

		if not ok then
			return false, type_errors.because(type_errors.subset(a_val, b_val), reason)
		end
	end

	return true
end

function META:Union(union--[[#: TUnion]])
	local copy = self:Copy()

	for _, e in ipairs(union.Data) do
		copy:AddType(e)
	end

	return copy
end

local function copy_val(
	val--[[#: TBaseType]],
	map--[[#: Map<|any, any|>]],
	copy_tables--[[#: nil | boolean]]
)
	if not val then return val end

	-- if it's already copied
	if map[val] then return map[val] end

	if val.Type == "table" and not copy_tables then
		return val
	else
		map[val] = (val--[[# as any]]):Copy(map, copy_tables)
	end

	return map[val]
end

function META:Copy(map--[[#: Map<|any, any|> | nil]], copy_tables--[[#: nil | boolean]])--[[#: TUnion]]
	map = map or {}

	if map[self] then return map[self] end

	local copy = META.New()
	map[self] = copy

	for i, obj in ipairs(self.Data) do
		add(copy, copy_val(obj, map, copy_tables))
	end

	copy:CopyInternalsFrom(self)
	return copy
end

function META:IsTruthy()
	for _, v in ipairs(self.Data) do
		if v:IsTruthy() then return true end
	end

	return false
end

function META:IsFalsy()
	for _, v in ipairs(self.Data) do
		if v:IsFalsy() then return true end
	end

	return false
end

function META:IsLiteral()
	for _, obj in ipairs(self.Data) do
		if not obj:IsLiteral() then return false end
	end

	return true
end

function META:SetLeftRightSource(l, r)
	self.left_right_source = {left = l, right = r}
end

function META:GetLeftRightSource()
	return self.left_right_source
end

function META:SetParentTable(tbl, key)
	self.parent_table = {table = tbl, key = key}
end

function META:GetParentTable()
	return self.parent_table
end

function META.New(data--[[#: nil | List<|TBaseType|>]])
	local self = setmetatable(
		{
			Type = "union",
			Data = {},
			LiteralDataCache = {},
			Falsy = false,
			Truthy = false,
			ReferenceType = false,
			suppress = false,
			left_right_source = false,
			parent_table = false,
			Contract = false,
			Parent = false,
			Upvalue = false,
			Parent = false,
		},
		META
	)

	if data then for _, v in ipairs(data) do
		self:AddType(v)
	end end

	return self
end

function META:Simplify()
	return #self.Data == 1 and self.Data[1] or self
end

function META:IsNumeric()
	for _, obj in ipairs(self.Data) do
		if not obj:IsNumeric() then return false end
	end

	return true
end

return {
	Union = META.New,
	Nilable = function(typ--[[#: TBaseType]])
		return META.New({typ, Nil()})
	end,
	Boolean = function()
		return META.New({True(), False()})
	end,
}
