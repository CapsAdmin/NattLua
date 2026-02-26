--ANALYZE
local math = _G.math
local assert = _G.assert
local error = _G.error
local tostring = _G.tostring
local tonumber = _G.tonumber
local setmetatable = _G.setmetatable
local type = _G.type
local error_messages = require("nattlua.error_messages")
local bit = require("nattlua.other.bit")
local loadstring = require("nattlua.other.loadstring")
local string_to_integer = require("nattlua.other.integer")
local jit = _G.jit
local False = require("nattlua.types.symbol").False
local shared = require("nattlua.types.shared")
local META = require("nattlua.types.base")()
--[[#local type TNumber = META.@SelfArgument]]
--[[#type TNumber.Type = "number"]]
--[[#local type TBaseType = TNumber]]
META.Type = "number"
META:GetSet("Data", false--[[# as number | false]])
META:GetSet("Hash", "")
META:IsSet("DontWiden", false)
local LNumberRange = require("nattlua.types" .. ".range"--[[# as any]]).LNumberRange--[[# as function=(TNumber, TNumber)>(TBaseType)]]

function META:SetData()
	if false--[[# as true]] then return end

	error("cannot mutate data")
end

--[[#local type TUnion = {
	@Name = "TUnion",
	Type = "union",
	GetLargestNumber = function=(self)>(TNumber | nil, nil | any),
}]]
local VERSION--[[#: string]] = jit and "LUAJIT" or _VERSION

local function compute_hash(num--[[#: nil | number]])
	if not num then return "N" end

	local s = tostring(tonumber(num))

	if VERSION == "LUAJIT" then return s end

	if s == "-nan" then return "nan" end

	if s:sub(-2) == ".0" then s = s:sub(1, -3) end

	return s
end

function META.New(data--[[#: number | nil]])
	return META.NewObject(
		{
			Type = META.Type,
			Data = data or false,
			TruthyFalsy = "truthy",
			Upvalue = false,
			Contract = false,
			DontWiden = false,
			Hash = compute_hash(data),
		}
	)
end

function META:GetLuaType()
	if type(self.Data) == "cdata" then return "cdata" end

	return self.Type
end

local function Number()
	return META.New()
end

local function LNumber(num--[[#: number | nil]])
	return META.New(num)
end

function META:GetHashForMutationTracking()
	if self:IsNan() then return nil end

	if self.Data then return self.Data end

	local upvalue = self:GetUpvalue()

	if upvalue then return upvalue:GetHashForMutationTracking() end

	return self
end

function META.Equal(a--[[#: TNumber]], b--[[#: TBaseType]])
	return shared.Equal(a, b)
end

function META:IsLiteral()
	return self.Data ~= false
end

function META:Widen()
	return Number()
end

function META:CopyLiteralness(obj--[[#: TNumber]])
	local self = self:Copy()

	if obj.Type == "range" then

	else
		if obj.Type == "union" then
			local x = obj:GetType("range")

			if x then return self end
		end

		if not obj:IsLiteral() then
			self.Data = false
			self.Hash = "N"
		end
	end

	return self
end

function META:Copy()--[[#: TNumber]]
	local copy = self.New(self.Data)
	copy:CopyInternalsFrom(self)
	copy.LengthSourceTable = self.LengthSourceTable
	return copy
end

function META.IsSubsetOf(a--[[#: TNumber]], b--[[#: TBaseType]])
	if b.Type == "tuple" then b = b:GetWithNumber(1) end

	if b.Type == "any" then return true end

	if b.Type == "union" then return b:IsTargetSubsetOfChild(a) end

	if b.Type == "range" then
		if a.Data and a.Data >= b:GetMin() and a.Data <= b:GetMax() then
			return true
		end

		return false, error_messages.subset(a, b)
	end

	if b.Type ~= "number" then return false, error_messages.subset(a, b) end

	if a.Data and b.Data then
		if a:IsNan() and b:IsNan() then return true end

		if a.Data == b.Data then return true end

		return false, error_messages.subset(a, b)
	elseif a.Data == false and b.Data == false then
		-- number contains number
		return true
	elseif a.Data and not b.Data then
		-- 42 subset of number?
		return true
	elseif not a.Data and b.Data then
		-- number subset of 42 ?
		return false, error_messages.subset(a, b)
	end

	-- number == number
	return true
end

function META:IsNan()--[[#: boolean]]
	return self.Data ~= self.Data
end

function META:IsInf()--[[#: boolean]]
	return self.Data and math.abs(self.Data) == math.huge
end

function META:__tostring()--[[#: string]]
	local n = self.Data

	if self:IsNan() then return "nan" end

	if self.Data then return tostring(self.Data) end

	return "number"
end

function META:UnpackRange()
	return self.Data, self.Data
end

do
	local inf = math.huge
	local operators--[[#: {[string] = function=(number, number)>(number)}]] = {
		["+"] = function(l, r)
			return l + r
		end,
		["-"] = function(l, r)
			return l - r
		end,
		["*"] = function(l, r)
			return l * r
		end,
		["/"] = function(l, r)
			return l / r
		end,
		["/idiv/"] = function(l, r)
			return (math.modf(l / r))
		end,
		["%"] = function(l, r)
			return l % r
		end,
		["^"] = function(l, r)
			return l ^ r
		end,
		["&"] = function(l, r)
			return bit.band(l, r)
		end,
		["|"] = function(l, r)
			return bit.bor(l, r)
		end,
		["~"] = function(l, r)
			return bit.bxor(l, r)
		end,
		["<<"] = function(l, r)
			return bit.lshift(l, r)
		end,
		[">>"] = function(l, r)
			return bit.rshift(l, r)
		end,
	}

	for k, v in pairs(operators) do
		operators[k] = function(l, r)
			if l == inf or r == inf then return inf end

			return v(l, r)
		end
	end

	function META.BinaryOperator(l--[[#: TNumber]], r--[[#: TBaseType]], op--[[#: keysof<|operators|>]])
		local func = operators[op]

		if not func then return nil, error_messages.binary(op, l, r) end

		if l.Data == false then return Number() end

		if r.Type == "range" then
			local l_min = l.Data
			local l_max = l.Data
			local r_min = r:GetMin()
			local r_max = r:GetMax()
			return LNumberRange(func(l_min, r_min), func(l_max, r_max))
		end

		if r.Data == false then return Number() end

		return LNumber(func(assert(l.Data), assert(r.Data)))
	end
end

do
	local operators--[[#: {[string] = function=(number)>(number)}]] = {
		["+"] = function(x)
			return x
		end,
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

	function META.PrefixOperator(x--[[#: TNumber]], op--[[#: keysof<|operators|>]])
		local func = operators[op]

		if op == "not" then return False() end

		if not x.Data then return Number() end

		local res = func(x.Data)
		local lcontract = x:GetContract()

		if lcontract then
			local min = lcontract.Data

			if min and min > res then
				return false, error_messages.number_underflow(x)
			end
		end

		return LNumber(res)
	end
end

function META:IsNumeric()
	return true
end

return {
	Number = Number,
	LNumber = LNumber,
	LNumberFromString = function(str--[[#: string]])
		local num

		if str:sub(1, 2) == "0b" then
			num = tonumber(str:sub(3), 2)
		elseif str:lower():sub(-3) == "ull" then
			num = string_to_integer(str)
		elseif str:lower():sub(-2) == "ll" then
			num = string_to_integer(str)
		else
			num = tonumber(str)
		end

		if not num then return nil end

		return LNumber(num)
	end,
	TNumber = TNumber,
}