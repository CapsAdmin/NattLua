local math = math
local assert = assert
local error = _G.error
local tostring = _G.tostring
local tonumber = _G.tonumber
local setmetatable = _G.setmetatable
local type_errors = require("nattlua.types.error_messages")
local bit = require("nattlua.other.bit")
local jit = _G.jit
local False = require("nattlua.types.symbol").False
local META = dofile("nattlua/types/base.lua")
--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TNumber"]]
--[[#type TNumber = META.@Self]]
--[[#type TNumber.DontWiden = boolean]]
META.Type = "number"
META:GetSet("Data", false--[[# as number | false]])

function META:SetData()
	if false--[[# as true]] then return end

	error("cannot mutate data")
end

--[[#local type TUnion = {
	@Name = "TUnion",
	Type = "union",
	GetLargestNumber = function=(self)>(TNumber | nil, nil | any),
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
			Type = "number",
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
	return META.New()
end

local function LNumber(num--[[#: number | nil]])
	return META.New(num)
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

function META.Equal(a--[[#: TNumber]], b--[[#: TBaseType]])
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
		if obj.Type == "number" and obj.Max then

		else
			if obj.Type == "union" then
				local x = (obj--[[# as any]]):GetType("number")

				if x then if x.Max then return self end end
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

function META.IsSubsetOf(a--[[#: TNumber]], b--[[#: TBaseType]])
	if b.Type == "tuple" then b = (b--[[# as any]]):GetWithNumber(1) end

	if b.Type == "any" then return true end

	if b.Type == "union" then
		return (b--[[# as any]]):IsTargetSubsetOfChild(a--[[# as any]])
	end

	if b.Type ~= "number" then return false, type_errors.subset(a, b) end

	if a.Data and b.Data then
		local a_min = a.Data--[[# as number]]
		local b_min = b.Data--[[# as number]]

		-- Compare against literals
		if a.Type == "number" and b.Type == "number" then
			if a:IsNan() and b:IsNan() then return true end
		end

		local a_max = a.Max or a_min
		local b_max = b.Max or b_min

		-- Check if a's range is entirely within b's range
		if a_min >= b_min and a_max <= b_max then return true end

		return false, type_errors.subset(a, b)
	elseif a.Data == false and b.Data == false then
		-- number contains number
		return true
	elseif a.Data and not b.Data then
		-- 42 subset of number?
		return true
	elseif not a.Data and b.Data then
		-- number subset of 42 ?
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
	local operators = {
		[">"] = function(a--[[#: number]], b--[[#: number]])
			return a > b
		end,
		["<"] = function(a--[[#: number]], b--[[#: number]])
			return a < b
		end,
		["<="] = function(a--[[#: number]], b--[[#: number]])
			return a <= b
		end,
		[">="] = function(a--[[#: number]], b--[[#: number]])
			return a >= b
		end,
	}

	local function compare(
		val--[[#: number]],
		min--[[#: number]],
		max--[[#: number]],
		operator--[[#: keysof<|operators|>]]
	)
		local func = operators[operator]

		if func(min, val) and func(max, val) then
			return true
		elseif not func(min, val) and not func(max, val) then
			return false
		end

		return nil
	end

	function META.LogicalComparison(a--[[#: TNumber]], b--[[#: TNumber]], operator--[[#: "=="]])--[[#: boolean | nil]]
		if a.Type ~= "number" then return nil end

		if b.Type ~= "number" then return nil end

		if not a.Data or not b.Data then return nil end

		if operator == "==" then
			local a_val = a.Data
			local b_val = b.Data

			if b_val then
				local max = a.Max

				if max and a_val then
					if b_val >= a_val and b_val <= max then return nil end

					return false
				end
			end

			if a_val then
				local max = b.Max

				if max and b_val then
					if a_val >= b_val and a_val <= max then return nil end

					return false
				end
			end

			if a_val and b_val then return a_val == b_val end

			return nil
		end

		if a.Data and b.Data then
			if a.Max and b.Max then
				local res_a = compare(b.Data, a.Data, b.Max, operator)
				local res_b = compare(a.Data, b.Data, a.Max, operator)

				if res_b == nil or res_a == nil then return nil end

				res_b = not res_b

				if res_a ~= nil and res_a == res_b then return res_a end

				return nil
			elseif a.Max then
				local res = compare(b.Data, a.Data, a.Max, operator)

				if res == nil then return nil end

				return res
			elseif b.Max then
				local res = compare(a.Data, b.Data, b.Max, operator)

				if res == nil then return nil end

				return not res
			end

			if operators[operator] then return operators[operator](a.Data, b.Data) end
		else
			return nil
		end

		if operators[operator] then return nil end

		return false, type_errors.binary(operator, a, b)
	end

	local max = math.max
	local min = math.min

	local function intersect(a_min, a_max, operator, b_min, b_max)
		if operator == "<" then
			if a_min < b_min and a_min < b_max and a_max < b_min and a_min < b_max then
				return min(a_min, b_max), min(a_max, b_max - 1), nil, nil
			end

			if a_min >= b_min and a_min >= b_max and a_max >= b_min and a_min >= b_max then
				return nil, nil, min(b_min, a_max), min(b_max, a_max)
			end

			return min(a_min, b_max),
			min(a_max, b_max - 1),
			min(b_min, a_max),
			min(b_max, a_max)
		elseif operator == ">" then
			if a_min > b_min and a_min > b_max and a_max > b_min and a_min > b_max then
				return max(a_min, b_max), max(a_max, b_max + 1), nil, nil
			end

			if a_min <= b_min and a_min <= b_max and a_max <= b_min and a_min <= b_max then
				return nil, nil, max(b_min, a_max), max(b_max, a_max)
			end

			return max(a_min, b_min + 1),
			max(a_max, b_min),
			max(b_min, a_min),
			max(b_max, b_min)
		elseif operator == "<=" then
			if a_min <= b_min and a_min <= b_max and a_max <= b_min and a_min <= b_max then
				return min(a_min, b_max), min(a_max, b_max), nil, nil
			end

			if a_min > b_min and a_min > b_max and a_max > b_min and a_min > b_max then
				return nil, nil, min(b_min, a_max), min(b_max, a_max)
			end

			return min(a_min, b_max),
			min(a_max, b_max),
			min(b_min, a_max),
			min(b_max, a_max - 1)
		elseif operator == ">=" then
			if a_min >= b_min and a_min >= b_max and a_max >= b_min and a_min >= b_max then
				return max(a_min, b_max), max(a_max, b_max), nil, nil
			end

			if a_min < b_min and a_min < b_max and a_max < b_min and a_min < b_max then
				return nil, nil, max(b_min, a_max), max(b_max, a_max)
			end

			return max(a_min, b_min),
			max(a_max, b_min),
			max(b_min, a_min + 1),
			max(b_max, b_min)
		elseif operator == "==" then
			if a_max < b_min or b_max < a_min then return nil, nil, b_min, b_max end

			if a_min == a_max and b_min == b_max and a_min == b_max then
				return a_min, a_max, nil, nil
			end

			if a_min <= b_max and b_min <= a_max then
				if a_min == a_max and min(a_max, b_max) == b_max then
					return max(a_min, b_min), min(a_max, b_max), b_min, b_max - 1
				end

				if a_min == a_max and max(a_min, b_min) == b_min then
					return max(a_min, b_min), min(a_max, b_max), b_min + 1, b_max
				end

				return max(a_min, b_min), min(a_max, b_max), b_min, b_max
			end
		elseif operator == "~=" then
			local x, y, z, w = intersect(b_min, b_max, "==", a_min, a_max)
			return z, w, x, y
		end
	end

	function META.IntersectComparison(a--[[#: TNumber]], b--[[#: TNumber]], operator--[[#: keysof<|operators|>]])--[[#: TNumber | nil,TNumber | nil]]
		-- TODO: not sure if this makes sense
		if a:IsNan() or b:IsNan() then return a, b end

		-- if a is a wide "number" then default to -inf..inf so we can narrow it down if b is literal
		local a_min = a.Data or -math.huge
		local a_max = a.Max or not a.Data and math.huge or a_min
		local b_min = b.Data or -math.huge
		local b_max = b.Max or not b.Data and math.huge or b_min
		local a_min_res, a_max_res, b_min_res, b_max_res = intersect(a_min, a_max, operator, b_min, b_max)
		local result_a, result_b

		if a_min_res and a_max_res then
			result_a = LNumberRange(a_min_res, a_max_res)
		end

		if b_min_res and b_max_res then
			result_b = LNumberRange(b_min_res, b_max_res)
		end

		return result_a, result_b
	end
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

	function META.BinaryOperator(l--[[#: TNumber]], r--[[#: TNumber]], op--[[#: keysof<|operators|>]])
		local func = operators[op]

		if l.Data and r.Data then
			local res = func(l.Data--[[# as number]], r.Data--[[# as number]])
			local lcontract = l:GetContract()--[[# as nil | TNumber]]

			if lcontract then
				if lcontract.Max and (res > lcontract.Max) then
					return false, type_errors.number_overflow(l, r)
				end

				local min = lcontract.Data

				if min and (min > res) then
					return false, type_errors.number_underflow(l, r)
				end
			end

			local obj = LNumber(res)

			if r.Max then obj.Max = func(l.Max or l.Data, r.Max) end

			if l.Max then obj.Max = func(l.Max, r.Max or r.Data) end

			obj.Hash = compute_hash(obj.Data, obj.Max)
			return obj
		end

		return Number()
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

	function META.PrefixOperator(x--[[#: TNumber]], op--[[#: keysof<|operators|>]])
		local func = operators[op]

		if op == "not" then return False() end

		if not x.Data then return Number() end

		local res = func(x.Data--[[# as number]])
		local lcontract = x:GetContract()--[[# as false | TNumber]]

		if lcontract then
			if lcontract.Max and res > lcontract.Max then
				return false, type_errors.number_overflow(x)
			end

			local min = lcontract.Data

			if min and min > res then
				return false, type_errors.number_underflow(x)
			end
		end

		if x.Max then return LNumberRange(res, func(x.Max or x.Data)) end

		return LNumber(res)
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

return {
	Number = Number,
	LNumberRange = LNumberRange,
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
