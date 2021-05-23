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

META:GetSet("Data", nil --[[# as number]])

local operators = {
		["-"] = function(l--[[#: number]])
			return -l
		end,
		["~"] = function(l--[[#: number]])
			return bit.bnot(l)
		end,
	}

function META:PrefixOperator(op--[[#: keysof<| operators |>]])
	if self:IsLiteral() then
		local num = self.New(operators[op](self:GetData())):SetLiteral(true)

		if self:GetMax() then
			num:SetMax(self:GetMax():PrefixOperator(op))
		end

		return num
	end

	return self.New()
end

function META.Equal(a--[[#: TNumber]], b--[[#: TNumber]])
	if a.Type ~= b.Type then return false end

	if a:IsLiteral() and b:IsLiteral() then
        -- nan
        if a:GetData() ~= a:GetData() and b:GetData() ~= b:GetData() then return true end
		return a:GetData() == b:GetData()
	end

	if a.Max and b.Max and a.Max:Equal(b.Max) then return true end
	if a.Max or b.Max then return false end
	if not a:IsLiteral() and not b:IsLiteral() then return true end
	return false
end

function META:GetLuaType()
	return self.Type
end

function META:Copy()
	local copy = self.New(self:GetData()):SetLiteral(self:IsLiteral())

	if self.Max then
		copy.Max = self.Max:Copy()
	end

	copy:CopyInternalsFrom(self)
	return copy
end

function META.IsSubsetOf(A --[[#: TNumber]], B --[[#: TNumber]])
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

			if B:GetMax() then
				if A:GetData() >= B:GetData() and A:GetData() <= B:GetMax():GetData() then return true end
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

META:GetSet("Max", nil --[[# as TNumber | nil]])

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
		self:SetData(nil)
		self.Max = nil
	end

	return self
end

local ops = {
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

local function compare(a--[[#: TNumber]], b--[[#: TNumber]], op--[[#: keysof<|ops|>]])
	local min = a:GetData()
	local max = a:GetMax():GetData()
	local val = b:GetData()
	local f = ops[op]

	if f(min, val) and f(max, val) then
		return true
	elseif not f(min, val) and not f(max, val) then
		return false
	end

	return nil
end

function META.LogicalComparison(a--[[#: TNumber]], b--[[#: TNumber]], op--[[#: keysof<|ops|>]])--[[#: boolean | nil]]
	if a:GetMax() and b:GetMax() then
		local res_a = compare(a, b, op)
		local res_b = not compare(b, a, op)
		if res_a ~= nil and res_a == res_b then return res_a end
		return nil
	end

	if a:GetMax() then
		local res = compare(a, b, op)
		if res == nil then return nil end
		return res
	end

	if ops[op] then return ops[op](a:GetData(), b:GetData()) end
	error("NYI " .. op)
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
