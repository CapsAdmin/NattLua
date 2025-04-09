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
META:GetSet("Data", false--[[# as number | false]])

function META:SetData()
	if false--[[# as true]] then return end

	error("cannot mutate data")
end

--[[#local type TUnion = {
	@Name = "TUnion",
	Type = "union",
	GetLargestNumber = function=(self)>(TRange | nil, nil | any),
}]]
local VERSION = jit and "LUAJIT" or _VERSION

local function tostring_number(num)
	local s = tostring(tonumber(num))

	if VERSION == "LUAJIT" then return s end

	if s == "-nan" then return "nan" end

	if s:sub(-2) == ".0" then s = s:sub(1, -3) end

	return s
end

local function compute_hash(min--[[#: any]], max--[[#: any]])
	if max then
		return tostring_number(min) .. ".." .. tostring_number(min)
	elseif min then
		return tostring_number(min)
	end

	return "N"
end

META:GetSet("Hash", ""--[[# as string]])

function META.New(min--[[#: number | nil]], max--[[#: number | nil]])
	local s = setmetatable(
		{
			Type = META.Type,
			Data = min or false,
			Max = max or false,
			Falsy = false,
			Truthy = true,
			ReferenceType = false,
			Upvalue = false,
			Parent = false,
			Contract = false,
			DontWiden = false,
			Hash = compute_hash(min, max),
		},
		META
	)
	return s
end

function META:GetLuaType()
	if type(self.Data) == "cdata" then return "cdata" end

	return self.Type
end

local function Number()
	return require("nattlua.types.number").Number()
end

local function LNumber(num--[[#: number | nil]])
	return require("nattlua.types.number").LNumber(num)
end

local function LNumberRange(from--[[#: number]], to--[[#: number]])
	return META.New(from, to)
end

function META:GetHashForMutationTracking()
	if self:IsNan() then return nil end

	if self.Max and self.Data then
		return self.Hash
	elseif self.Data then
		return self.Data
	end

	local upvalue = self:GetUpvalue()

	if upvalue then return upvalue:GetHashForMutationTracking() end

	return self
end

function META.Equal(a--[[#: TRange]], b--[[#: TBaseType]])
	if a.Type ~= b.Type then return false, "types differ" end

	do
		return a.Hash == b.Hash
	end

	if a.Max and a.Max == b.Max and a.Data == b.Data then
		return true, "max values are equal"
	end

	if a.Max or b.Max then return false, "max value mismatch" end

	if not a.Data and not b.Data then
		return true, "no literal data in either value"
	else
		if a:IsNan() and b:IsNan() then return true, "both values are nan" end

		return a.Data == b.Data, "literal values are equal"
	end

	return false, "values are not equal"
end

function META:IsLiteral()
	return self.Data ~= false and self.Max == false
end

META:IsSet("DontWiden", false)

function META:Widen()
	return Number()
end

function META:CopyLiteralness(obj--[[#: TBaseType]])
	if self.ReferenceType == obj.ReferenceType and self.Data == obj.Data then
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

			if not obj:IsLiteral() then
				self.Data = false
				self.Hash = "N"
			end
		end
	end

	return self
end

function META:Copy()
	local copy = self.New(self.Data, self.Max)--[[# as any]] -- TODO: figure out inheritance
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

	if a.Data and b.Data then
		if a:GetMin() >= b:GetMin() and a:GetMax() <= b:GetMax() then return true end

		return false, type_errors.subset(a, b)
	end

	-- number == number
	return true
end

function META:IsNan()
	return self.Data ~= self.Data
end

function META:IsInf()
	local n = self.Data
	return math.abs(n--[[# as number]]) == math.huge
end

function META:__tostring()
	local n = self.Data
	local s--[[#: string]]

	if self:IsNan() then s = "nan" end

	s = tostring(n)

	if self.Max then s = s .. ".." .. tostring(self.Max) end

	if self.Data then return s end

	return "number"
end

META:GetSet("Max", false--[[# as number | false]])

function META:SetMax(val--[[#: number]])
	if false--[[# as true]] then return end

	error("cannot mutate data")
end

function META:GetMax()
	return self.Max
end

function META:GetMin()
	return self.Data
end

function META:UnpackRange()
	return self.Data, self.Max or self.Data
end

do
	local inf = math.huge
	local operators--[[#: {[string] = function=(number, number)>(number)}]] = {
		["+"] = function(l, r)
			return l + r
		end,
		["-"] = function(l, r)
			if l == inf or r == inf then return inf end

			return l - r
		end,
		["*"] = function(l, r)
			return l * r
		end,
		["/"] = function(l, r)
			if l == inf or r == inf then return inf end

			return l / r
		end,
		["/idiv/"] = function(l, r)
			if l == inf or r == inf then return inf end

			return (math.modf(l / r))
		end,
		["%"] = function(l, r)
			if l == inf or r == inf then return inf end

			return l % r
		end,
		["^"] = function(l, r)
			return l ^ r
		end,
		["&"] = function(l, r)
			if l == inf or r == inf then return inf end

			return bit.band(l, r)
		end,
		["|"] = function(l, r)
			if l == inf or r == inf then return inf end

			return bit.bor(l, r)
		end,
		["~"] = function(l, r)
			if l == inf or r == inf then return inf end

			return bit.bxor(l, r)
		end,
		["<<"] = function(l, r)
			if l == inf or r == inf then return inf end

			return bit.lshift(l, r)
		end,
		[">>"] = function(l, r)
			if l == inf or r == inf then return inf end

			return bit.rshift(l, r)
		end,
	}

	function META.BinaryOperator(l--[[#: TRange]], r--[[#: any]], op--[[#: keysof<|operators|>]])
		local func = operators[op]

		if not func then return nil, type_errors.binary(op, l, r) end

		local l_min = l.Data--[[# as number]]
		local l_max = l.Max--[[# as number]]
		local r_min = r.Data--[[# as number]]
		local r_max = (r.Type == "range" and r.Max or r.Data)--[[# as number]]

		if r_max == false then
			r_min = -math.huge
			r_max = math.huge
		end

		return LNumberRange(func(l_min, r_min), func(l_max, r_max))
	end
end

do
	local operators--[[#: {[string] = function=(number)>(number)}]] = {
		["-"] = function(x)
			return -x
		end,
		["~"] = function(x)
			return bit.bnot(x)
		end,
	}

	if bit == _G.bit32 then
		operators["~"] = function(x)
			local result = bit32.bnot(x)

			if result > 0x7FFFFFFF then return result - 0x100000000 end

			return result
		end
	end

	function META.PrefixOperator(x--[[#: TRange]], op--[[#: keysof<|operators|>]])
		if op == "not" then return False() end

		local func = operators[op]

		if not func then return nil, type_errors.prefix(op, x) end

		return LNumberRange(func(x.Data--[[# as number]]), func(x.Max--[[# as number]]))
	end
end

local function string_to_integer(str--[[#: string]])
	if
		not jit and
		(
			_VERSION == "Lua 5.1" or
			_VERSION == "Lua 5.2" or
			_VERSION == "Lua 5.3" or
			_VERSION == "Lua 5.4"
		)
	then
		str = str:lower():sub(-3)

		if str == "ull" then
			str = str:sub(1, -4)
		elseif str:sub(-2) == "ll" then
			str = str:sub(1, -3)
		end
	end

	return assert(load("return " .. str))()--[[# as number]]
end

function META:IsNumeric()
	return type(self.Data) == "number" and type(self.Max) == "number"
end

return {
	LNumberRange = LNumberRange,
	TRange = TRange,
}
