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

	if #a.Data ~= #b.Data then return false end

	for i = 1, #a.Data do
		local ok = false
		local a = a.Data[i]--[[# as TBaseType]]

		for i = 1, #b.Data do
			local b = b.Data[i]--[[# as TBaseType]]
			a.suppress = true--[[# as boolean]]
			ok = a:Equal(b)
			a.suppress = false--[[# as boolean]]

			if ok then break end
		end

		if not ok then
			a.suppress = false--[[# as boolean]]
			return false
		end
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

	for _, v in ipairs(self.Data) do
		table.insert(s, tostring(v))
	end

	if not s[1] then
		self.suppress = false
		return "|"
	end

	self.suppress = false

	if #s == 1 then return s[1] .. "|" end

	table.sort(s, sort)
	return table.concat(s, " | ")
end

local function is_literal(obj)
	return (
			(
				obj.Type == "number" and
				not obj.Max and
				not obj:IsNan()
			)
			or
			obj.Type == "string"
		)
		and
		obj.Data ~= nil
end

function META:AddType(e--[[#: TBaseType]])
	if e.Type == "union" then
		for _, v in ipairs(e.Data) do
			self:AddType(v)
		end

		return self
	end

	for _, v in ipairs(self.Data) do
		if v:Equal(e) then
			if
				e.Type ~= "function" or
				e:GetContract() or
				(
					e:GetFunctionBodyNode() and
					(
						e:GetFunctionBodyNode() == v:GetFunctionBodyNode()
					)
				)
			then
				return self
			end
		end
	end

	if e.Type == "string" or e.Type == "number" then
		local sup = e

		for i = #self.Data, 1, -1 do
			local sub = self.Data[i]--[[# as TBaseType]] -- TODO, prove that the for loop will always yield TBaseType?
			if sub.Type == sup.Type then
				if sub:IsSubsetOf(sup) then table.remove(self.Data, i) end
			end
		end
	end

	--if is_literal(e) then self.LiteralDataCache[e.Data] = true end
	table.insert(self.Data, e)
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
			table.remove(self.Data, i)

			break
		end
	end

	return self
end

function META:Clear()
	self.Data = {}
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

				table.insert(errors, err)
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
	local errors = {}

	for i, obj in ipairs(self.Data) do
		local ok, reason = key:IsSubsetOf(obj)

		if ok then return obj end

		errors[i] = reason
	end

	return false, errors
end

function META:IsEmpty()
	return self.Data[1] == nil
end

function META:RemoveCertainlyFalsy()
	local copy = self:Copy()

	for _, v in ipairs(self.Data) do
		if v:IsCertainlyFalse() then copy:RemoveType(v) end
	end

	return copy
end

function META:GetTruthy()
	local copy = self:Copy()

	for _, obj in ipairs(self.Data) do
		if not obj:IsTruthy() then copy:RemoveType(obj) end
	end

	return copy
end

function META:GetFalsy()
	local copy = self:Copy()

	for _, obj in ipairs(self.Data) do
		if not obj:IsFalsy() then copy:RemoveType(obj) end
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
		if obj.Type == "symbol" and obj.Data == nil then

		else
			if obj.Type ~= typ then return false end
		end
	end

	return true
end

function META:HasType(typ--[[#: string]])
	return self:GetType(typ) ~= false
end

function META:CanBeNil()
	for _, obj in ipairs(self.Data) do
		if obj.Type == "symbol" and obj:GetData() == nil then return true end
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
	if b.Type == "tuple" then b = b:Get(1) end

	if b.Type == "any" then return true end

	if b.Type ~= "union" then b = META.New({b}) end

	if a:HasType("any") then return true end

	if a:IsEmpty() then
		return false, type_errors.because(type_errors.subset(a, b), "union is empty")
	end

	for _, a_val in ipairs(a.Data) do
		local b_val, reason = b:Get(a_val)

		if not b_val then
			return false, type_errors.because(type_errors.table_index(b, a_val), reason)
		end

		local ok, reason = a_val:IsSubsetOf(b_val)

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

function META.New(data--[[#: nil | List<|TBaseType|>]])
	local self = setmetatable(
		{
			Data = {},
			--LiteralDataCache = {},
			Falsy = false,
			Truthy = false,
			ReferenceType = false,
			suppress = false,
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