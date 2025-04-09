local LNumber = require("nattlua.types.number").LNumber
local LNumberRange = require("nattlua.types.range").LNumberRange
--[[#local type NumericType = any]]
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

local function intersect_comparison(a--[[#: NumericType]], b--[[#: NumericType]], operator--[[#: keysof<|operators|>]])--[[#: NumericType | nil,NumericType | nil]]
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
		if a_min_res == a_max_res then
			result_a = LNumber(a_min_res)
		else
			result_a = LNumberRange(a_min_res, a_max_res)
		end
	end

	if b_min_res and b_max_res then
		if b_min_res == b_max_res then
			result_b = LNumber(b_min_res)
		else
			result_b = LNumberRange(b_min_res, b_max_res)
		end
	end

	return result_a, result_b
end

return intersect_comparison
