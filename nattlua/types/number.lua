local math = math
local assert = assert
local error = _G.error
local tostring = _G.tostring
local tonumber = _G.tonumber
local setmetatable = _G.setmetatable
local type_errors = require("nattlua.types.error_messages")
local bit = _G.bit32 or _G.bit
local jit = _G.jit
local META = dofile("nattlua/types/base.lua")
local False = require("nattlua.types.symbol").False
--[[#local type TBaseType = META.TBaseType]]
--[[#type META.@Name = "TNumber"]]
--[[#type TNumber = META.@Self]]
META.Type = "number"
META:GetSet("Data", nil--[[# as number | nil]])
--[[#local type TUnion = {
	@Name = "TUnion",
	Type = "union",
	GetLargestNumber = function=(self)>(TNumber | nil, nil | any),
}]]

function META:GetHash()
	if self:IsNan() then return nil end

	if self:IsLiteral() then
		if self.Max then
			local hash = self.Max:GetHash()

			if hash and self.Data then
				return "__@type@__" .. self.Type .. self.Data .. ".." .. hash
			end
		end

		return self.Data
	end

	local upvalue = self:GetUpvalue()

	if upvalue then
		return "__@type@__" .. upvalue:GetHash() .. "_" .. self.Type
	end

	if not jit then
		return "__@type@__" .. self.Type .. ("_%s"):format(tostring(self))
	end

	return "__@type@__" .. self.Type .. ("_%p"):format(self)
end

function META.Equal(a--[[#: TNumber]], b--[[#: TBaseType]])
	if a.Type ~= b.Type then return false end

	if not a:IsLiteral() and not b:IsLiteral() then return true end

	if a:IsLiteral() and b:IsLiteral() then
		if a:IsNan() and b:IsNan() then return true end

		return a:GetData() == b:GetData()
	end

	local a_max = a.Max
	local b_max = b.Max

	if a_max then if b_max then if a_max:Equal(b_max) then return true end end end

	if a_max or b_max then return false end

	if not a:IsLiteral() and not b:IsLiteral() then return true end

	return false
end

function META:CopyLiteralness(num--[[#: TNumber]])
	if num.Type == "number" and num:GetMax() then
		if self:IsSubsetOf(num) then
			if num:IsReferenceType() then
				self:SetLiteral(true)
				self:SetReferenceType(true)
			end

			self:SetData(num:GetData())
			self:SetMax(num:GetMax())
		end
	else
		if num:IsReferenceType() then
			self:SetLiteral(true)
			self:SetReferenceType(true)
		else
			self:SetLiteral(num:IsLiteral())
		end
	end
end

function META:Copy()
	local copy = self.New():SetLiteral(self:IsLiteral()):SetData(self:GetData())
	local max = self.Max

	if max then copy.Max = max:Copy() end

	copy:CopyInternalsFrom(self)
	return copy--[[# as any]] -- TODO: figure out inheritance
end

function META.IsSubsetOf(a--[[#: TNumber]], b--[[#: TBaseType]])
	if b.Type == "tuple" then b = (b--[[# as any]]):Get(1) end

	if b.Type == "any" then return true end

	if b.Type == "union" then
		return (b--[[# as any]]):IsTargetSubsetOfChild(a--[[# as any]])
	end

	if b.Type ~= "number" then return false, type_errors.subset(a, b) end

	if a:IsLiteral() and b:IsLiteral() then
		local a_min = a:GetData()--[[# as number]]
		local b_min = b:GetData()--[[# as number]]
		local a_max = a:GetMaxLiteral() or a_min
		local b_max = b:GetMaxLiteral() or b_min

		-- Compare against literals
		if a.Type == "number" and b.Type == "number" then
			if a:IsNan() and b:IsNan() then return true end
		end

		-- Check if a's range is entirely within b's range
		if a_min >= b_min and a_max <= b_max then return true end

		return false, type_errors.subset(a, b)
	elseif a:GetData() == nil and b:GetData() == nil then
		-- number contains number
		return true
	elseif a:IsLiteral() and not b:IsLiteral() then
		-- 42 subset of number?
		return true
	elseif not a:IsLiteral() and b:IsLiteral() then
		-- number subset of 42 ?
		return false, type_errors.subset(a, b)
	end

	-- number == number
	return true
end

function META:IsNan()
	local n = self:GetData()
	return n ~= n
end

function META:IsInf()
	local n = self:GetData()
	return math.abs(n--[[# as number]]) == math.huge
end

function META:__tostring()
	local n = self:GetData()
	local s--[[#: string]]

	if self:IsNan() then s = "nan" end

	s = tostring(n)

	if self:GetMax() then s = s .. ".." .. tostring(self:GetMax()) end

	if self:IsLiteral() then return s end

	return "number"
end

META:GetSet("Max", nil--[[# as TNumber | nil]])

function META:SetMax(val--[[#: TBaseType | TUnion]])
	local err

	if val.Type == "union" then
		val, err = (val--[[# as any]]):GetLargestNumber()

		if not val then return val, err end
	end

	if val.Type ~= "number" then
		return false, type_errors.subset(val, "number")
	end

	if self:Equal(val) then return self end

	if val:IsLiteral() then
		self.Max = val
	else
		self:SetLiteral(false)
		self:SetData(nil)
		self.Max = nil
	end

	return self
end

function META:GetMaxLiteral()
	return self.Max and self.Max:GetData() or nil
end

function META:GetMinLiteral()
	return self:GetData()
end

function META:UnpackRange()
	return self:GetMinLiteral(), self:GetMaxLiteral() or self:GetMinLiteral()
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
		if not a:IsLiteral() or not b:IsLiteral() then return nil end

		if operator == "==" then
			local a_val = a:GetData()
			local b_val = b:GetData()

			if b_val then
				local max = a:GetMax()
				local max = max and max:GetData()

				if max and a_val then
					if b_val >= a_val and b_val <= max then return nil end

					return false
				end
			end

			if a_val then
				local max = b:GetMax()
				local max = max and max:GetData()

				if max and b_val then
					if a_val >= b_val and a_val <= max then return nil end

					return false
				end
			end

			if a_val and b_val then return a_val == b_val end

			return nil
		end

		local a_val = a:GetData()
		local b_val = b:GetData()

		if a_val and b_val then
			local a_max = a:GetMaxLiteral()
			local b_max = b:GetMaxLiteral()

			if a_max and b_max then
				local res_a = compare(b_val, a_val, b_max, operator)
				local res_b = compare(a_val, b_val, a_max, operator)

				if res_b == nil or res_a == nil then return nil end

				res_b = not res_b

				if res_a ~= nil and res_a == res_b then return res_a end

				return nil
			elseif a_max then
				local res = compare(b_val, a_val, a_max, operator)

				if res == nil then return nil end

				return res
			elseif b_max then
				local res = compare(a_val, b_val, b_max, operator)

				if res == nil then return nil end

				return not res
			end

			if operators[operator] then return operators[operator](a_val, b_val) end
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
		local a_min = a:GetData() or -math.huge
		local a_max = a:GetMaxLiteral() or not a:GetData() and math.huge or a_min
		local b_min = b:GetData() or -math.huge
		local b_max = b:GetMaxLiteral() or not b:GetData() and math.huge or b_min
		local a_min_res, a_max_res, b_min_res, b_max_res = intersect(a_min, a_max, operator, b_min, b_max)
		local result_a, result_b

		if a_min_res and a_max_res then
			result_a = META.New():SetLiteral(true):SetData(a_min_res):SetMax(META.New():SetLiteral(true):SetData(a_max_res))
		end

		if b_min_res and b_max_res then
			result_b = META.New():SetLiteral(true):SetData(b_min_res):SetMax(META.New():SetLiteral(true):SetData(b_max_res))
		end

		return result_a, result_b
	end
end

do
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

	function META.BinaryOperator(l--[[#: TNumber]], r--[[#: TNumber]], op--[[#: keysof<|operators|>]])
		local func = operators[op]

		if l:IsLiteral() and r:IsLiteral() then
			local res = func(l:GetData()--[[# as number]], r:GetData()--[[# as number]])
			local lcontract = l:GetContract()--[[# as nil | TNumber]]

			if lcontract then
				if res > lcontract:GetMaxLiteral() and lcontract:GetMaxLiteral() then
					return false, type_errors.number_overflow(l, r)
				end

				local min = lcontract:GetMinLiteral()

				if min and min > res then
					return false, type_errors.number_underflow(l, r)
				end
			end

			local obj = META.New():SetLiteral(true):SetData(res)

			if r:GetMax() then
				obj:SetMax(l.BinaryOperator(l:GetMax() or l, r:GetMax()--[[# as TNumber]], op))
			end

			if l:GetMax() then
				obj:SetMax(l.BinaryOperator(l:GetMax()--[[# as TNumber]], r:GetMax() or r, op))
			end

			return obj
		end

		return META.New()
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

	function META.PrefixOperator(x--[[#: TNumber]], op--[[#: keysof<|operators|>]])
		local func = operators[op]

		if op == "not" then return False() end

		if not x:IsLiteral() then return META.New() end

		local res = func(x:GetData()--[[# as number]])
		local lcontract = x:GetContract()--[[# as nil | TNumber]]

		if lcontract then
			if res > lcontract:GetMaxLiteral() and lcontract:GetMaxLiteral() then
				return false, type_errors.number_overflow(x)
			end

			local min = lcontract:GetMinLiteral()

			if min and min > res then
				return false, type_errors.number_underflow(x)
			end
		end

		local obj = META.New():SetLiteral(true):SetData(res)

		if x:GetMax() then
			obj:SetMax(x.PrefixOperator(x:GetMax() or x--[[# as TNumber]], op))
		end

		return obj
	end
end

function META.New()
	return setmetatable(
		{
			Data = nil,
			Falsy = false,
			Truthy = true,
			Literal = false,
			ReferenceType = false,
		},
		META
	)
end

local function string_to_integer(str--[[#: string]])
	if not jit and _VERSION == "Lua 5.1" then
		str = str:lower():gsub("ull", "")
		str = str:gsub("ll", "")
	end

	return assert(loadstring("return " .. str))()--[[# as number]]
end

return {
	Number = META.New,
	LNumberRange = function(from--[[#: number]], to--[[#: number]])
		return META.New():SetData(from):SetLiteral(true):SetMax(META.New():SetData(to):SetLiteral(true))
	end,
	LNumber = function(num--[[#: number | nil]])
		return META.New():SetData(num):SetLiteral(true)
	end,
	LNumberFromString = function(str--[[#: string]])
		local num = tonumber(str)

		if not num then
			if str:sub(1, 2) == "0b" then
				num = tonumber(str:sub(3), 2)
			elseif str:lower():sub(-3) == "ull" then
				num = string_to_integer(str)
			elseif str:lower():sub(-2) == "ll" then
				num = string_to_integer(str)
			end
		end

		if not num then return nil end

		return META.New():SetData(num):SetLiteral(true)
	end,
	TNumber = TNumber,
}