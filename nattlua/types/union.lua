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
local table_insert = _G.table.insert
local table_remove = _G.table.remove
local table_sort = require("nattlua.other.sort")

--[[#local type { TNumber } = require("nattlua.types.number")]]

local META = dofile("nattlua/types/base.lua")
--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TUnion"]]
--[[#type TUnion = META.@Self]]
--[[#type TUnion.Data = List<|TBaseType|>]]
--[[#type TUnion.suppress = boolean]]
META.Type = "union"

function META:GetHash()
	return tostring(self)
end

function META.Equal(a--[[#: TUnion]], b--[[#: TBaseType]])
	if a.suppress then return true end

	if b.Type ~= "union" and #a.Data == 1 and a.Data[1] then
		return a.Data[1]:Equal(b)
	end

	if a.Type ~= b.Type then return false end

	local b = b--[[# as TUnion]]
	local len = #a.Data

	if len ~= #b.Data then return false end

	for i = 1, len do
		local a = a.Data[i]--[[# as TBaseType]]
		local ok = false

		if a.Type == "union" or a.Type == "table" then
			a.suppress = true--[[# as boolean]]
		end
		for i = 1, len do
			local b = b.Data[i]--[[# as TBaseType]]
			
			ok = a:Equal(b)
			
			if ok then break end
		end
		if a.Type == "union" or a.Type == "table" then
			a.suppress = false--[[# as boolean]]
		end

		if not ok then return false end
	end

	return true
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

function META:AddType(e--[[#: TBaseType]])
	if e.Type == "union" then
		for _, v in ipairs(e.Data) do
			self:AddType(v)
		end

		return self
	end

	if (e.Type == "string" or e.Type == "number") and not e:IsLiteral() then
		for i = #self.Data, 1, -1 do
			local sub = self.Data[i]--[[# as TBaseType]] -- TODO, prove that the for loop will always yield TBaseType?
			if sub.Type == e.Type then self.Data[#self.Data] = nil end
		end

		self.Data[#self.Data + 1] = e
		return self
	end

	for i = 1, #self.Data do
		local v = self.Data[i]--[[# as TBaseType]]

		if v:Equal(e) then return self end
	end

	self.Data[#self.Data + 1] = e
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

	for i, v in ipairs(self.Data) do
		if v:Equal(e) then
			table_remove(self.Data, i)

			break
		end
	end

	return self
end

function META:Clear()
	self.Data = {}
end

local has_clear, table_clear = pcall(require, "table.clear")

if has_clear then
	function META:Clear()
		(table_clear--[[# as any]])(self.Data)
	end
end

function META:HasTuples()
	for _, obj in ipairs(self.Data) do
		if obj.Type == "tuple" then return true end
	end

	return false
end

function META:GetAtTupleIndex(i--[[#: number]])
	if not self:HasTuples() then return self:Simplify() end

	local val--[[#: any]]
	local errors = {}

	for _, obj in ipairs(self.Data) do
		if obj.Type == "tuple" then
			local found, err = obj:Get(i)

			if found then
				if val then val = self.New({val, found}) else val = found end
			else
				if val then val = self.New({val, Nil()}) else val = Nil() end

				table_insert(errors, err)
			end
		else
			if val then
				-- a non tuple in the union would be treated as a tuple with the value repeated
				val = self.New({val--[[# as any]], obj})
			elseif i == 1 then
				val = obj
			else
				val = Nil()
			end
		end
	end

	if not val then return false, errors end

	if val.Type == "union" and val:GetCardinality() == 1 then
		return val.Data[1]
	end

	return val
end

function META:Get(key--[[#: TBaseType]])
	local errors

	for i, obj in ipairs(self.Data) do
		local ok, reason = key:IsSubsetOf(obj)
		
		if ok then return obj end

		errors = errors or {}
		errors[i] = reason
	end

	return false, errors
end

function META:IsEmpty()
	return self.Data[1] == nil
end

function META:RemoveCertainlyFalsy()
	local copy = META.New()

	for _, obj in ipairs(self.Data) do
		if not obj:IsCertainlyFalse() then copy.Data[#copy.Data + 1] = obj end
	end

	return copy
end

function META:GetTruthy()
	local copy = META.New()

	for _, obj in ipairs(self.Data) do
		if obj:IsTruthy() then copy.Data[#copy.Data + 1] = obj end
	end

	return copy
end

function META:GetFalsy()
	local copy = META.New()

	for _, obj in ipairs(self.Data) do
		if obj:IsFalsy() then copy.Data[#copy.Data + 1] = obj end
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

function META.IsSubsetOf(a--[[#: TUnion]], b--[[#: TBaseType]])
	if a.suppress then return true, "suppressed" end

	if b.Type == "tuple" then b = b:Get(1) end

	if b.Type == "any" then return true end

	if b.Type ~= "union" then b = META.New({b}) end

	if a:HasType("any") then return true end

	if a:IsEmpty() then
		return false, type_errors.because(type_errors.subset(a, b), "union is empty")
	end

	for _, a_val in ipairs(a.Data) do
		a.suppress = true
		local b_val, reason = b:Get(a_val)
		a.suppress = false
		if not b_val then
			return false, type_errors.because(type_errors.table_index(b, a_val), reason)
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

function META:Copy(map--[[#: Map<|any, any|> | nil]], copy_tables--[[#: nil | boolean]])
	map = map or {}
	local copy = META.New()
	map[self] = map[self] or copy

	for _, e in ipairs(self.Data) do
		if e.Type == "table" and not copy_tables then
			copy:AddType(e)
		else
			copy:AddType(e:Copy(map, copy_tables))
		end
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
			--LiteralDataCache = {},
			Falsy = false,
			Truthy = false,
			ReferenceType = false,
			suppress = false,
			left_right_source = false,
			UniqueID = false,
			parent_table = false,
			Contract = false,
			Name = false,
			MetaTable = false,
			TypeOverride = false,
			BaseTable = false,
			Parent = false,
			Upvalue = false,
			Parent = false,
			Node = false,
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

return {
	Union = META.New,
	Nilable = function(typ--[[: TBaseType]] )
		return META.New({typ, Nil()})
	end,
	Boolean = function()
		return META.New({True(), False()})
	end,
}
