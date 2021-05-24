local ipairs = _G.ipairs
local table = require("table")
local error = _G.error
local tostring = _G.tostring
local type_errors = require("nattlua.types.error_messages")
local bit = require("bit")
local META = dofile("nattlua/types/base.lua")
META.Type = "number"
--[[#type META.@Name = "TNumber"]]
--[[#type TNumber = META.@Self]]
META:GetSet("Data", nil--[[# as number]])
local operators = {
		["-"] = function(l--[[#: number]])
			return -l
		end,
		["~"] = function(l--[[#: number]])
			return bit.bnot(l)
		end,
	}

function META:PrefixOperator(op--[[#: keysof<|operators|>]])
	if self:IsLiteral() then
		local num = self.New(operators[op](self:GetData())):SetLiteral(true)
		local max = self:GetMax()

		if max then
			num:SetMax(max:PrefixOperator(op))
		end

		return num
	end

	return self.New(nil--[[# as number]]) -- hmm
end

function META.Equal(a--[[#: TNumber]], b--[[#: TNumber]])
	if a.Type ~= b.Type then return false end

	if a:IsLiteral() and b:IsLiteral() then
        -- nan
        if a:GetData() ~= a:GetData() and b:GetData() ~= b:GetData() then return true end
		return a:GetData() == b:GetData()
	end

	local a_max = a.Max
	local b_max = b.Max

	if a_max then
		if b_max then
			if a_max:Equal(b_max) then return true end
		end
	end

	if a_max or b_max then return false end
	if not a:IsLiteral() and not b:IsLiteral() then return true end
	return false
end

function META:GetLuaType()
	return self.Type
end

function META:Copy()
	local copy = self.New(self:GetData()):SetLiteral(self:IsLiteral())
	local max = self.Max

	if max then
		copy.Max = max:Copy()
	end

	copy:CopyInternalsFrom(self)
	return copy
end

function META.IsSubsetOf(A--[[#: TNumber]], B--[[#: TNumber]])
	if B.Type == "tuple" and B:GetLength() == 1 then
		B = B:Get(1)
	end

	if B.Type == "union" then
		local errors = {}

		for _, b in ipairs(B:GetData()) do
			local ok, reason = A:IsSubsetOf(b)
			if ok then return true end
			table.insert(errors, reason)
		end

		return type_errors.subset(A, B, errors)
	end

	if A.Type == "any" then return true end
	if B.Type == "any" then return true end

	if B.Type == "number" then
		if A:IsLiteral() == true and B:IsLiteral() == true then
            -- compare against literals

            -- nan
            if A.Type == "number" and B.Type == "number" then
				if A:GetData() ~= A:GetData() and B:GetData() ~= B:GetData() then return true end
			end

			if A:GetData() == B:GetData() then return true end
			local max = B:GetMaxLiteral()

			if max then
				if A:GetData() >= B:GetData() and A:GetData() <= max then return true end
			end

			return type_errors.subset(A, B)
		elseif A:GetData() == nil and B:GetData() == nil then
            -- number contains number
            return true
		elseif A:IsLiteral() and not B:IsLiteral() then
            -- 42 subset of number?
            return true
		elseif not A:IsLiteral() and B:IsLiteral() then
            -- number subset of 42 ?
            return type_errors.subset(A, B)
		end

        -- number == number
        return true
	else
		return type_errors.type_mismatch(A, B)
	end

	error("this shouldn't be reached")
	return false
end

function META:__tostring()
	local n = self:GetData()

	if n ~= n then
		n = "nan"
	end

	local s = tostring(n)

	if self:GetMax() then
		s = s .. ".." .. tostring(self:GetMax())
	end

	if self:IsLiteral() then return s end
	if self:GetData() then return "number(" .. s .. ")" end
	return "number"
end

META:GetSet("Max", nil--[[# as TNumber | nil]])

function META:SetMax(val)
	local err

	if val.Type == "union" then
		val, err = val:GetLargestNumber()
		if not val then return val, err end
	end

	if val.Type ~= "number" then return type_errors.other("max must be a number, got " .. tostring(val)) end

	if val:IsLiteral() then
		self.Max = val
	else
		self:SetLiteral(false)
		self:SetData(nil--[[# as number]]) -- hmm
		self.Max = nil
	end

	return self
end

function META:GetMaxLiteral()
	return self.Max and self.Max:GetData()
end

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

local function compare(val--[[#: number]], min--[[#: number]], max--[[#: number]], operator--[[#: keysof<|operators|>]])
	local func = operators[operator]

	if func(min, val) and func(max, val) then
		return true
	elseif not func(min, val) and not func(max, val) then
		return false
	end

	return nil
end

function META.LogicalComparison(a--[[#: TNumber]], b--[[#: TNumber]], operator--[[#: keysof<|operators|>]])--[[#: boolean | nil]]
	local a_val = a:GetData()
	local b_val = b:GetData()
	if not a_val then return nil end
	if not b_val then return nil end
	local a_max = a:GetMaxLiteral()
	local b_max = b:GetMaxLiteral()

	if a_max then
		if b_max then
			local res_a = compare(b_val, a_val, b_max, operator)
			local res_b = not compare(a_val, b_val, a_max, operator)
			if res_a ~= nil and res_a == res_b then return res_a end
			return nil
		end
	end

	if a_max then
		local res = compare(b_val, a_val, a_max, operator)
		if res == nil then return nil end
		return res
	end

	if operators[operator] then return operators[operator](a_val, b_val) end
	error("NYI " .. operator)
end

function META:IsFalsy()
	return false
end

function META:IsTruthy()
	return true
end

function META.New(data--[[#: number]])
	return setmetatable({Data = data}, META)
end

return {Number = META.New}
