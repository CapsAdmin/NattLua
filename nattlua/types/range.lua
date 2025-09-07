--ANALYZE
local math = _G.math
local assert = _G.assert
local error = _G.error
local tostring = _G.tostring
local tonumber = _G.tonumber
local setmetatable = _G.setmetatable
local type = _G.type
local type_errors = require("nattlua.types.error_messages")
local bit = require("nattlua.other.bit")
local jit = _G.jit
local False = require("nattlua.types.symbol").False

--[[#local type { TNumber } = require("nattlua.types.number")]]

local META = require("nattlua.types.base")()
--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TRange"]]
--[[#type TRange = META.@Self]]
--[[#type TRange.DontWiden = boolean]]
--[[#type TRange.Type = "range"]]
--[[#type TRange.Data = nil]]
META.Type = "range"
META:GetSet("MinNumber", false--[[# as TNumber]])
META:GetSet("MaxNumber", false--[[# as TNumber]])
META:GetSet("Hash", ""--[[# as string]])
--[[#local type TUnion = {
	@Name = "TUnion",
	Type = "union",
	GetLargestNumber = function=(self)>(TRange | nil, nil | any),
}]]
local VERSION = jit and "LUAJIT" or _VERSION

local function compute_hash(min--[[#: TNumber]], max--[[#: TNumber]])
	return min:GetHash() .. ".." .. max:GetHash()
end

local mod = nil

local function LNumber(num--[[#: number | nil]])
	mod = mod or require("nattlua.types.number")
	return mod.LNumber(num)
end

function META.New(min--[[#: TNumber]], max--[[#: TNumber]])
	return META.NewObject(
		{
			Type = META.Type,
			MinNumber = min,
			MaxNumber = max,
			Falsy = false,
			Truthy = true,
			ReferenceType = false,
			Upvalue = false,
			Parent = false,
			Contract = false,
			Hash = compute_hash(min, max),
			DontWiden = false,
		}
	)
end

function META:GetLuaType()
	if type(self:GetMin()) == "cdata" then return "cdata" end

	return self.Type
end

local function LNumberRange(from--[[#: number]], to--[[#: number]])
	assert(type(from) == "number")
	assert(type(to) == "number")
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
	return false
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
				local x = obj:GetType("range")

				if x then return self end
			end
		end
	end

	return self
end

function META:Copy()
	local copy = LNumberRange(self:GetMin(), self:GetMax())
	copy:CopyInternalsFrom(self)
	return copy
end

function META.IsSubsetOf(a--[[#: TRange]], b--[[#: TBaseType]])
	if b.Type == "tuple" then b = b:GetWithNumber(1) end

	if b.Type == "any" then return true end

	if b.Type == "union" then return b:IsTargetSubsetOfChild(a) end

	if b.Type == "number" and not b.Data then return true end

	if b.Type ~= "range" then return false, type_errors.subset(a, b) end

	if a:GetMin() >= b:GetMin() and a:GetMax() <= b:GetMax() then return true end

	return false, type_errors.subset(a, b)
end

function META:__tostring()
	return tostring(self:GetMin()) .. ".." .. tostring(self:GetMax())
end

function META:GetMax()--[[#: number]]
	return self.MaxNumber.Data--[[# as number]] -- always literal numbers
end

function META:GetMin()--[[#: number]]
	return self.MinNumber.Data--[[# as number]] -- always literal numbers
end

function META:UnpackRange()
	return self:GetMin(), self:GetMax()
end

function META:IsNan()
	return self:GetMin() ~= self:GetMin() or self:GetMax() ~= self:GetMax()
end

function META.BinaryOperator(l--[[#: TRange]], r--[[#: TRange | TNumber]], op--[[#: string]])
	if r.Type == "range" then
		return META.New(
			assert(l.MinNumber:BinaryOperator(r.MinNumber, op)),
			assert(l.MaxNumber:BinaryOperator(r.MaxNumber, op))
		)
	elseif r.Type == "number" then
		local r_min = r
		local r_max = r
		local num = r:GetData()

		if op == "%" then
			if not num then
				r_min = LNumber(-math.huge)
				r_max = LNumber(math.huge)
			else
				r_max = LNumber(num - 1)
			end

			return META.New(assert(l.MinNumber:BinaryOperator(r_min, op)), r_max)
		else
			if not num then
				r_min = LNumber(-math.huge)
				r_max = LNumber(math.huge)
			end

			return META.New(
				assert(l.MinNumber:BinaryOperator(r_min, op)),
				assert(l.MaxNumber:BinaryOperator(r_max, op))
			)
		end
	end

	error("NYI")
end

function META.PrefixOperator(x--[[#: TRange]], op--[[#: string]])
	if op == "not" then return False() end

	local min = assert(x.MinNumber:PrefixOperator(op))
	local max = assert(x.MaxNumber:PrefixOperator(op))

	if min.Type ~= "number" then return False() end

	if max.Type ~= "number" then return False() end

	return META.New(min, max)
end

function META:IsNumeric()
	return type(self:GetMin()) == "number" and type(self:GetMax()) == "number"
end

return {
	LNumberRange = LNumberRange,
	TRange = TRange,
}
