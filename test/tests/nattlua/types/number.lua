local LNumberRange = require("nattlua.types.range").LNumberRange
local LNumber = require("nattlua.types.number").LNumber
local Number = require("nattlua.types.number").Number
local Any = require("nattlua.types.any").Any
local stringx = require("nattlua.other.string")

test("a literal number should be contained within all numbers", function()
	assert(LNumber(42):IsSubsetOf(Number()))
end)

test("all numbers should not be contained within a literal number", function()
	assert(not Number():IsSubsetOf(LNumber(42)))
end)

test("42 should be contained within any", function()
	assert(LNumber(42):IsSubsetOf(Any()))
end)

test("any should be contained within 42", function()
	assert(Any():IsSubsetOf(LNumber(42)))
end)

test("42 should be contained within 32..52", function()
	assert(LNumber(42):IsSubsetOf(LNumberRange(32, 52)))
end)

test("32..52 should not be contained within 42", function()
	assert(not LNumberRange(32, 52):IsSubsetOf(LNumber(42)))
end)

test("a non-literal number should be contained within all numbers", function()
	assert(Number():IsSubsetOf(Number()))
end)

test("a literal number should not contain all numbers", function()
	assert(not Number():IsSubsetOf(LNumber(42)))
end)

test("two identical literal numbers should be subsets of each other", function()
	assert(LNumber(10):IsSubsetOf(LNumber(10)))
end)

test("a number range should contain a literal number within its range", function()
	assert(LNumber(50):IsSubsetOf(LNumberRange(0, 100)))
end)

test("a number range should not contain a literal number outside its range", function()
	assert(not LNumber(101):IsSubsetOf(LNumberRange(0, 100)))
end)

test("a smaller range should be a subset of a larger range that contains it", function()
	assert(LNumberRange(25, 75):IsSubsetOf(LNumberRange(0, 100)))
end)

test("a larger range should not be a subset of a smaller range contained within it", function()
	assert(not LNumberRange(0, 100):IsSubsetOf(LNumberRange(25, 75)))
end)

test("a non-literal number should be a subset of any", function()
	assert(Number():IsSubsetOf(Any()))
end)

test("a literal number at the lower bound of a range should be a subset of that range", function()
	assert(LNumber(32):IsSubsetOf(LNumberRange(32, 52)))
end)

test("a literal number at the upper bound of a range should be a subset of that range", function()
	assert(LNumber(52):IsSubsetOf(LNumberRange(32, 52)))
end)

test("a literal number just outside the lower bound of a range should not be a subset of that range", function()
	assert(not LNumber(31):IsSubsetOf(LNumberRange(32, 52)))
end)

test("a literal number just outside the upper bound of a range should not be a subset of that range", function()
	assert(not LNumber(53):IsSubsetOf(LNumberRange(32, 52)))
end)

if false then
	test("LogicalComparison of two literal numbers should work correctly", function()
		equal(LNumber(10):LogicalComparison(LNumber(5), ">"), true)
		equal(LNumber(5):LogicalComparison(LNumber(10), "<"), true)
		equal(LNumber(10):LogicalComparison(LNumber(10), "=="), true)
		equal(LNumber(10):LogicalComparison(LNumber(5), "<="), false)
	end)

	test("LogicalComparison of a literal number and a number range should work correctly", function()
		equal(LNumber(20):LogicalComparison(LNumberRange(0, 10), ">"), true)
		equal(LNumber(5):LogicalComparison(LNumberRange(0, 10), "<"), nil) -- Indeterminate
		equal(LNumber(15):LogicalComparison(LNumberRange(0, 10), "=="), false)
	end)

	test("Zero should be handled correctly in ranges and comparisons", function()
		assert(LNumber(0):LogicalComparison(LNumber(1), "<") == true)
		assert(LNumber(0):LogicalComparison(LNumber(-1), ">") == true)
	end)

	test("Zero should be handled correctly in ranges and comparisons", function()
		assert(LNumber(0):LogicalComparison(LNumber(1), "<") == true)
		assert(LNumber(0):LogicalComparison(LNumber(-1), ">") == true)
	end)
end

test("BinaryOperator should work correctly for literal numbers", function()
	equal(LNumber(5):BinaryOperator(LNumber(3), "+"):GetData(), 8)
	equal(LNumber(10):BinaryOperator(LNumber(2), "*"):GetData(), 20)
	equal(LNumber(15):BinaryOperator(LNumber(3), "/"):GetData(), 5)
end)

test("PrefixOperator should work correctly for literal numbers", function()
	equal(LNumber(5):PrefixOperator("-"):GetData(), -5)
	equal(LNumber(5):PrefixOperator("~"):GetData(), -6) -- Bitwise NOT
end)

test("Overlapping ranges should not be subsets of each other", function()
	assert(not LNumberRange(0, 50):IsSubsetOf(LNumberRange(25, 75)))
	assert(not LNumberRange(25, 75):IsSubsetOf(LNumberRange(0, 50)))
end)

test("A range should be a subset of itself", function()
	local range = LNumberRange(10, 20)
	assert(range:IsSubsetOf(range))
end)

test("An open-ended range should contain all numbers above its lower bound", function()
	local openRange = LNumberRange(100, math.huge)
	assert(LNumber(1000):IsSubsetOf(openRange))
	assert(not LNumber(99):IsSubsetOf(openRange))
end)

test("Negative numbers should work correctly in ranges", function()
	local negativeRange = LNumberRange(-50, -10)
	assert(LNumber(-30):IsSubsetOf(negativeRange))
	assert(not LNumber(-60):IsSubsetOf(negativeRange))
	assert(not LNumber(0):IsSubsetOf(negativeRange))
end)

test("Zero should be handled correctly in ranges and comparisons", function()
	assert(LNumber(0):IsSubsetOf(LNumberRange(-10, 10)))
end)

test("Non-integer numbers should work correctly", function()
	assert(LNumber(3.14):IsSubsetOf(LNumberRange(3, 4)))
	assert(LNumber(2.5):BinaryOperator(LNumber(1.5), "+"):GetData() == 4)
end)

-- Helper function to check if two ranges are equal
local function rangesEqual(range1, range2)
	local a, b = range1:UnpackRange()
	local c, d = range2:UnpackRange()
	local a_is_nan = a ~= a and c ~= c
	local b_is_nan = b ~= b and c ~= c

	if a == c and b == d then return true end

	return a_is_nan and b_is_nan
end

-- Addition tests
test("Adding two number ranges", function()
	local range1 = LNumberRange(1, 5)
	local range2 = LNumberRange(10, 20)
	local result = range1:BinaryOperator(range2, "+")
	assert(rangesEqual(result, LNumberRange(11, 25)))
end)

test("Adding a number range and a literal number", function()
	local range = LNumberRange(0, 10)
	local num = LNumber(5)
	local result = range:BinaryOperator(num, "+")
	assert(rangesEqual(result, LNumberRange(5, 15)))
end)

-- Subtraction tests
test("Subtracting two number ranges", function()
	local range1 = LNumberRange(10, 20)
	local range2 = LNumberRange(1, 5)
	local result = range1:BinaryOperator(range2, "-")
	assert(rangesEqual(result, LNumberRange(9, 15)))
end)

test("Subtracting a literal number from a number range", function()
	local range = LNumberRange(10, 20)
	local num = LNumber(5)
	local result = range:BinaryOperator(num, "-")
	assert(rangesEqual(result, LNumberRange(5, 15)))
end)

-- Multiplication tests
test("Multiplying two positive number ranges", function()
	local range1 = LNumberRange(2, 4)
	local range2 = LNumberRange(3, 5)
	local result = range1:BinaryOperator(range2, "*")
	assert(rangesEqual(result, LNumberRange(6, 20)))
end)

test("Multiplying a positive and a negative number range", function()
	local range1 = LNumberRange(2, 4)
	local range2 = LNumberRange(-3, -1)
	local result = range1:BinaryOperator(range2, "*")
	assert(rangesEqual(result, LNumberRange(-6, -4)))
end)

-- Division tests
test("Dividing two positive number ranges", function()
	local range1 = LNumberRange(10, 20)
	local range2 = LNumberRange(2, 4)
	local result = range1:BinaryOperator(range2, "/")
	assert(rangesEqual(result, LNumber(5)))
end)

-- Edge case tests
test("Adding a number range to zero", function()
	local range = LNumberRange(-5, 5)
	local zero = LNumber(0)
	local result = range:BinaryOperator(zero, "+")
	assert(rangesEqual(result, range))
end)

test("Multiplying a number range by zero", function()
	local range = LNumberRange(-5, 5)
	local zero = LNumber(0)
	local result = range:BinaryOperator(zero, "*")
	assert(rangesEqual(result, LNumber(0)))
end)

test("Arithmetic with infinite ranges", function()
	local positiveInf = LNumberRange(0, math.huge)
	local negativeInf = LNumberRange(-math.huge, 0)
	local result = positiveInf:BinaryOperator(negativeInf, "+")
	assert(rangesEqual(result, LNumberRange(-math.huge, math.huge)))
end)

do
	local function brute_force_intersect(a, b, operator)
		local a_min, a_max = a:UnpackRange()
		local b_min, b_max = b:UnpackRange()
		local a_res_min
		local a_res_max
		local b_res_min
		local b_res_max
		local func = load("local a, b = ... return a " .. operator .. " b")

		for x = a_min, a_max do
			for y = b_min, b_max do
				if func(x, y) then
					if not a_res_min then
						a_res_min = x
					else
						a_res_min = math.min(a_res_min, x)
					end

					if not a_res_max then
						a_res_max = x
					else
						a_res_max = math.max(a_res_max, x)
					end
				else
					if not b_res_min then
						b_res_min = y
					else
						b_res_min = math.min(b_res_min, y)
					end

					if not b_res_max then
						b_res_max = y
					else
						b_res_max = math.max(b_res_max, y)
					end
				end
			end
		end

		local new_a
		local new_b

		if a_res_min then
			if a_res_min == a_res_max then
				new_a = LNumber(a_res_min)
			else
				new_a = LNumberRange(a_res_min, a_res_max)
			end
		end

		if b_res_min then
			if b_res_min == b_res_max then
				new_b = LNumber(b_res_min)
			else
				new_b = LNumberRange(b_res_min, b_res_max)
			end
		end

		print(new_a, new_b)
		return new_a, new_b
	end

	local function range_tostring(a, b)
		if a == b then return tostring(a) end

		return tostring(a) .. ", " .. tostring(b)
	end

	local intersect_comparison = require("nattlua.analyzer.intersect_comparison")

	local function check(a, op, b)
		local expect = range_tostring(brute_force_intersect(a, b, op))
		local result = range_tostring(intersect_comparison(a, b, op))

		do
			local input = stringx.replace(range_tostring(a, b), ", ", " " .. op .. " ")

			if expect ~= result then
				error("(" .. input .. ") = (" .. result .. ") - FAIL: expected " .. expect)
			else

			--print("(" .. input .. ") = (" .. result .. ") - OK")
			end
		end
	end

	local max = 2

	for _, op in ipairs({"<", ">", "<=", ">=", "==", "~="}) do
		for x = -max, max do
			for y = x, max do
				for z = -max, max do
					for w = z, max do
						if x ~= x and y ~= y and z ~= w then
							check(LNumberRange(x, y), op, LNumberRange(z, w))
						end
					end
				end
			end
		end
	end

	do
		local at, af, bt, bf = intersect_comparison(LNumberRange(-math.huge, math.huge), LNumberRange(-5, 5), ">")
		assert(rangesEqual(at, LNumberRange(-4, math.huge)))
		assert(rangesEqual(af, LNumberRange(-math.huge, 5)))
	end

	do
		local at, af, bt, bf = intersect_comparison(LNumberRange(1, math.huge), LNumberRange(5, 10), "<")
		assert(rangesEqual(at, LNumberRange(1, 9)))
		assert(rangesEqual(af, LNumberRange(5, math.huge)))
	end

	do
		local at, af, bt, bf = intersect_comparison(LNumberRange(-math.huge, math.huge), LNumberRange(5, 10), "<")
		assert(rangesEqual(at, LNumberRange(-math.huge, 9)))
		assert(rangesEqual(af, LNumberRange(5, math.huge)))
	end

	do
		local nan = math.huge / math.huge
		local at, af, bt, bf =  intersect_comparison(LNumberRange(nan, nan), LNumberRange(5, 10), "<")
		assert(rangesEqual(at, LNumberRange(nan, nan)))
		assert(rangesEqual(af, LNumberRange(5, 10)))
	end

	do
		local at, af, bt, bf = intersect_comparison(LNumber(0), LNumberRange(-math.huge, math.huge), "<")
		assert(at:Equal(LNumber(0)))
		assert(af:Equal(LNumber(0)))
		assert(rangesEqual(bt, LNumberRange(1, math.huge)))
		assert(rangesEqual(bf, LNumberRange(-math.huge, 0)))
	end

	do
		local at, af, bt, bf = intersect_comparison(LNumber(0), Number(), ">")
		assert(at:Equal(LNumber(0)))
		assert(af:Equal(LNumber(0)))
		assert(rangesEqual(bt, LNumberRange(-math.huge, -1)))
		assert(rangesEqual(bf, LNumberRange(0, math.huge)))
	end
end
