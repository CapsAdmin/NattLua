local math = math
local assert = assert
local error = _G.error
local tostring = _G.tostring
local tonumber = _G.tonumber
local setmetatable = _G.setmetatable
local type = _G.type
local type_errors = require("nattlua.types.error_messages")
local bit = require("nattlua.other.bit")
local jit = _G.jit
local False = require("nattlua.types.symbol").False
local META = dofile("nattlua/types/base.lua")
--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TRange"]]
--[[#type TRange = META.@Self]]
--[[#type TRange.DontWiden = boolean]]
META.Type = "range"
META:GetSet("Min", false--[[# as number | false]])
--[[#local type TUnion = {
	@Name = "TUnion",
	Type = "union",
	GetLargestNumber = function=(self)>(TRange | nil, nil | any),
}]]
local VERSION = jit and "LUAJIT" or _VERSION

local function compute_hash(min--[[#: any]], max--[[#: any]])
	return min:GetHash() .. ".." .. max:GetHash()
end

META:GetSet("Hash", ""--[[# as string]])

local function LNumber(num--[[#: number | nil]])
	return require("nattlua.types.number").LNumber(num)
end

function META.New(min--[[#: number | nil]], max--[[#: number | nil]])
	return setmetatable(
		{
			Type = META.Type,
			Min = min,
			Max = max,
			Falsy = false,
			Truthy = true,
			ReferenceType = false,
			Upvalue = false,
			Parent = false,
			Contract = false,
			Hash = compute_hash(min, max),
		},
		META
	)
end

function META:GetLuaType()
	if type(self:GetMin()) == "cdata" then return "cdata" end

	return self.Type
end

local function LNumberRange(from--[[#: number]], to--[[#: number]])
	return META.New(LNumber(from), LNumber(to))
end

function META:GetHashForMutationTracking()
	if self:IsNan() then return nil end

	return self.Hash
end

function META.Equal(a--[[#: TRange]], b--[[#: TBaseType]])
	return a.Hash == b.Hash
end

function META:IsLiteral()
	return true
end

function META:CopyLiteralness(obj--[[#: TBaseType]])
	if self.ReferenceType == obj.ReferenceType and self:Equal(obj) then
		return self
	end

	local self = self:Copy()

	if obj:IsReferenceType() then
		self:SetReferenceType(true)
	else
		if obj.Type == "range" then

		else
			if obj.Type == "union" then
				local x = (obj--[[# as any]]):GetType("range")

				if x then return self end
			end
		end
	end

	return self
end

function META:Copy()
	local copy = LNumberRange(self:GetMin(), self:GetMax())--[[# as any]] -- TODO: figure out inheritance
	copy:CopyInternalsFrom(self--[[# as any]])
	return copy
end

function META.IsSubsetOf(a--[[#: TRange]], b--[[#: TBaseType]])
	if b.Type == "tuple" then b = (b--[[# as any]]):GetWithNumber(1) end

	if b.Type == "any" then return true end

	if b.Type == "union" then
		return (b--[[# as any]]):IsTargetSubsetOfChild(a--[[# as any]])
	end

	if b.Type == "number" and not b.Data then return true end

	if b.Type ~= "range" then return false, type_errors.subset(a, b) end

	if a:GetMin() >= b:GetMin() and a:GetMax() <= b:GetMax() then return true end

	return false, type_errors.subset(a, b)
end

function META:__tostring()
	return tostring(self:GetMin()) .. ".." .. tostring(self:GetMax())
end

META:GetSet("Max", false--[[# as number | false]])

function META:SetMax(val--[[#: number]])
	if false--[[# as true]] then return end

	error("cannot mutate data")
end

function META:GetMax()
	return self.Max.Data
end

function META:GetMin()
	return self.Min.Data
end

function META:UnpackRange()
	return self:GetMin(), self:GetMax()
end

function META:IsNan()
	return self:GetMin() ~= self:GetMin() or self:GetMax() ~= self:GetMax()
end

function META.BinaryOperator(l--[[#: TRange]], r--[[#: any]], op--[[#: string]])
	if r.Type == "range" then
		return META.New(l.Min:BinaryOperator(r.Min, op), l.Max:BinaryOperator(r.Max, op))
	elseif r.Type == "number" then
		local r_min = r
		local r_max = r

		if op == "%" then
			if not r:IsLiteral() then
				r_min = LNumber(-math.huge)
				r_max = LNumber(math.huge)
			else
				r_max = LNumber(r:GetData() - 1)
			end

			return META.New(l.Min:BinaryOperator(r_min, op), r_max)
		else
			if not r:IsLiteral() then
				r_min = LNumber(-math.huge)
				r_max = LNumber(math.huge)
			end

			return META.New(l.Min:BinaryOperator(r_min, op), l.Max:BinaryOperator(r_max, op))
		end
	end

	error("NYI")
end

function META.PrefixOperator(x--[[#: TRange]], op--[[#: string]])
	if op == "not" then return False() end

	return META.New(x.Min:PrefixOperator(op), x.Max:PrefixOperator(op))
end

function META:IsNumeric()
	return type(self:GetMin()) == "number" and type(self:GetMax()) == "number"
end

return {
	LNumberRange = LNumberRange,
	TRange = TRange,
}
