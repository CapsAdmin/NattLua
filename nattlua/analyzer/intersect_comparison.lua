local LNumber = require("nattlua.types.number").LNumber
local LNumberRange = require("nattlua.types.range").LNumberRange
local max = math.max
local min = math.min

local function intersect(a_min, a_max, operator, b_min, b_max)
	if operator == "<" then
		-- Case 1: A < B is always true (A's upper bound < B's lower bound)
		if a_max < b_min then
			return a_min, a_max, b_min, b_max, nil, nil, nil, nil
		end

		-- Case 2: A < B is always false (A's lower bound ≥ B's upper bound)
		if a_min >= b_max then
			return nil, nil, nil, nil, a_min, a_max, b_min, b_max
		end

		-- Case 3: Ranges overlap, narrowing needed
		-- TRUE branch (A < B):
		local a_min_true = a_min -- A's lower bound doesn't change
		local a_max_true = math.min(a_max, b_max - 1) -- A must be less than B's maximum
		local b_min_true = math.max(b_min, a_min + 1) -- B must be greater than A's minimum
		local b_max_true = b_max -- B's upper bound doesn't change
		-- FALSE branch (A ≥ B):
		local a_min_false = math.max(a_min, b_min) -- A must be at least B's minimum
		local a_max_false = a_max -- A's upper bound doesn't change
		local b_min_false = b_min -- B's lower bound doesn't change
		local b_max_false = math.min(b_max, a_max) -- B can't exceed A's maximum
		return a_min_true,
		a_max_true,
		b_min_true,
		b_max_true,
		a_min_false,
		a_max_false,
		b_min_false,
		b_max_false
	elseif operator == ">" then
		-- Return value structure: 
		-- a_min_true, a_max_true, b_min_true, b_max_true, a_min_false, a_max_false, b_min_false, b_max_false
		-- Case 1: A > B is always true (A's lower bound > B's upper bound)
		if a_min > b_max then
			return a_min, a_max, b_min, b_max, nil, nil, nil, nil
		end

		-- Case 2: A > B is always false (A's upper bound ≤ B's lower bound)
		if a_max <= b_min then
			return nil, nil, nil, nil, a_min, a_max, b_min, b_max
		end

		-- Case 3: Ranges overlap, narrowing needed
		-- TRUE branch (A > B):
		local a_min_true = math.max(a_min, b_min + 1) -- A must be greater than B's minimum
		local a_max_true = a_max -- A's upper bound doesn't change
		local b_min_true = b_min -- B's lower bound doesn't change
		local b_max_true = math.min(b_max, a_max - 1) -- B must be less than A's maximum
		-- FALSE branch (A ≤ B):
		local a_min_false = a_min -- A's lower bound doesn't change
		local a_max_false = math.min(a_max, b_max) -- A can't exceed B's maximum
		local b_min_false = math.max(b_min, a_min) -- B must be at least A's minimum
		local b_max_false = b_max -- B's upper bound doesn't change
		return a_min_true,
		a_max_true,
		b_min_true,
		b_max_true,
		a_min_false,
		a_max_false,
		b_min_false,
		b_max_false
	elseif operator == "<=" then
		-- Case 1: A <= B is always true (A's upper bound <= B's lower bound)
		if a_max <= b_min then
			return a_min, a_max, b_min, b_max, nil, nil, nil, nil
		end

		-- Case 2: A <= B is always false (A's lower bound > B's upper bound)
		if a_min > b_max then
			return nil, nil, nil, nil, a_min, a_max, b_min, b_max
		end

		-- Case 3: Ranges overlap, narrowing needed
		-- TRUE branch (A <= B):
		local a_min_true = a_min -- A's lower bound doesn't change
		local a_max_true = math.min(a_max, b_max) -- A must be less than or equal to B's maximum
		local b_min_true = math.max(b_min, a_min) -- B must be at least A's minimum
		local b_max_true = b_max -- B's upper bound doesn't change
		-- FALSE branch (A > B):
		local a_min_false = math.max(a_min, b_max + 1) -- A must be greater than B's maximum
		local a_max_false = a_max -- A's upper bound doesn't change
		local b_min_false = b_min -- B's lower bound doesn't change
		local b_max_false = math.min(b_max, a_min - 1) -- B must be less than A's minimum
		return a_min_true,
		a_max_true,
		b_min_true,
		b_max_true,
		a_min_false,
		a_max_false,
		b_min_false,
		b_max_false
	elseif operator == ">=" then
		-- Case 1: A >= B is always true (A's lower bound >= B's upper bound)
		if a_min >= b_max then
			return a_min, a_max, b_min, b_max, nil, nil, nil, nil
		end

		-- Case 2: A >= B is always false (A's upper bound < B's lower bound)
		if a_max < b_min then
			return nil, nil, nil, nil, a_min, a_max, b_min, b_max
		end

		-- Case 3: Ranges overlap, narrowing needed
		-- TRUE branch (A >= B):
		local a_min_true = math.max(a_min, b_min) -- A must be at least B's minimum
		local a_max_true = a_max -- A's upper bound doesn't change
		local b_min_true = b_min -- B's lower bound doesn't change
		local b_max_true = math.min(b_max, a_max) -- B can't exceed A's maximum
		-- FALSE branch (A < B):
		local a_min_false = a_min -- A's lower bound doesn't change
		local a_max_false = math.min(a_max, b_min - 1) -- A must be less than B's minimum
		local b_min_false = math.max(b_min, a_max + 1) -- B must be greater than A's maximum
		local b_max_false = b_max -- B's upper bound doesn't change
		return a_min_true,
		a_max_true,
		b_min_true,
		b_max_true,
		a_min_false,
		a_max_false,
		b_min_false,
		b_max_false
	elseif operator == "==" then
		-- Case 1: A == B is impossible (non-overlapping ranges)
		if a_max < b_min or b_max < a_min then
			return nil, nil, nil, nil, a_min, a_max, b_min, b_max
		end

		-- Case 2: A == B is always true (both are the same single value)
		if a_min == a_max and b_min == b_max and a_min == b_min then
			return a_min, a_max, b_min, b_max, nil, nil, nil, nil
		end

		-- Case 3: Ranges overlap, narrowing needed
		-- TRUE branch (A == B): intersection of the two ranges
		local a_min_true = math.max(a_min, b_min)
		local a_max_true = math.min(a_max, b_max)
		local b_min_true = a_min_true -- For equality, the ranges must have the same values
		local b_max_true = a_max_true
		-- FALSE branch (A != B): all values where they don't overlap
		local a_min_false1 = a_min
		local a_max_false1 = math.min(a_max, b_min - 1)
		local a_min_false2 = math.max(a_min, b_max + 1)
		local a_max_false2 = a_max
		local b_min_false1 = b_min
		local b_max_false1 = math.min(b_max, a_min - 1)
		local b_min_false2 = math.max(b_min, a_max + 1)
		local b_max_false2 = b_max
		-- Combine the false ranges if possible
		local a_min_false, a_max_false

		if a_max_false1 >= a_min_false1 and a_max_false2 >= a_min_false2 then
			a_min_false = math.min(a_min_false1, a_min_false2)
			a_max_false = math.max(a_max_false1, a_max_false2)
		elseif a_max_false1 >= a_min_false1 then
			a_min_false = a_min_false1
			a_max_false = a_max_false1
		elseif a_max_false2 >= a_min_false2 then
			a_min_false = a_min_false2
			a_max_false = a_max_false2
		else
			a_min_false = nil
			a_max_false = nil
		end

		local b_min_false, b_max_false

		if b_max_false1 >= b_min_false1 and b_max_false2 >= b_min_false2 then
			b_min_false = math.min(b_min_false1, b_min_false2)
			b_max_false = math.max(b_max_false1, b_max_false2)
		elseif b_max_false1 >= b_min_false1 then
			b_min_false = b_min_false1
			b_max_false = b_max_false1
		elseif b_max_false2 >= b_min_false2 then
			b_min_false = b_min_false2
			b_max_false = b_max_false2
		else
			b_min_false = nil
			b_max_false = nil
		end

		return a_min_true,
		a_max_true,
		b_min_true,
		b_max_true,
		a_min_false,
		a_max_false,
		b_min_false,
		b_max_false
	elseif operator == "~=" then
		-- Implement ~= as the logical inverse of ==
		local a_min_true, a_max_true, b_min_true, b_max_true, a_min_false, a_max_false, b_min_false, b_max_false = intersect(a_min, a_max, "==", b_min, b_max)
		-- Swap the true and false branches to represent the logical NOT
		return a_min_false,
		a_max_false,
		b_min_false,
		b_max_false,
		a_min_true,
		a_max_true,
		b_min_true,
		b_max_true
	end
end

local function intersect_comparison(a--[[#: any]], b--[[#: any]], operator--[[#: string]])--[[#: any | nil,any | nil]]
	-- TODO: not sure if this makes sense
	if a:IsNan() or b:IsNan() then return a, b end

	-- if a is a wide "number" then default to -inf..inf so we can narrow it down if b is literal
	local a_min = a.Type == "range" and a:GetMin() or a.Data or a.Data or -math.huge
	local a_max = a.Type == "range" and a:GetMax() or a.Data or not a.Data and math.huge or a_min
	local b_min = b.Type == "range" and b:GetMin() or b.Data or b.Data or -math.huge
	local b_max = b.Type == "range" and b:GetMax() or b.Data or not b.Data and math.huge or b_min
	local a_min_res_true, a_max_res_true, b_min_res_true, b_max_res_true, a_min_res_false, a_max_res_false, b_min_res_false, b_max_res_false = intersect(a_min, a_max, operator, b_min, b_max)
	local result_a_true, result_a_false, result_b_true, result_b_false

	if a_min_res_true and a_max_res_true then
		if a_min_res_true == a_max_res_true then
			result_a_true = LNumber(a_min_res_true)
		else
			result_a_true = LNumberRange(a_min_res_true, a_max_res_true)
		end
	end

	if a_min_res_false and a_max_res_false then
		if a_min_res_false == a_max_res_false then
			result_a_false = LNumber(a_min_res_false)
		else
			result_a_false = LNumberRange(a_min_res_false, a_max_res_false)
		end
	end

	if b_min_res_true and b_max_res_true then
		if b_min_res_true == b_max_res_true then
			result_b_true = LNumber(b_min_res_true)
		else
			result_b_true = LNumberRange(b_min_res_true, b_max_res_true)
		end
	end

	if b_min_res_false and b_max_res_false then
		if b_min_res_false == b_max_res_false then
			result_b_false = LNumber(b_min_res_false)
		else
			result_b_false = LNumberRange(b_min_res_false, b_max_res_false)
		end
	end

	return result_a_true, result_a_false, result_b_true, result_b_false
end

return intersect_comparison
