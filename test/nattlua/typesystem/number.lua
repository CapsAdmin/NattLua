local LNumberRange = require("nattlua.types.number").LNumberRange
local LNumber = require("nattlua.types.number").LNumber
local Number = require("nattlua.types.number").Number
local Any = require("nattlua.types.any").Any

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

test("LogicalComparison of two literal numbers should work correctly", function()
	assert(LNumber(10):LogicalComparison(LNumber(5), ">") == true)
	assert(LNumber(5):LogicalComparison(LNumber(10), "<") == true)
	assert(LNumber(10):LogicalComparison(LNumber(10), "==") == true)
	assert(LNumber(10):LogicalComparison(LNumber(5), "<=") == false)
end)

test("LogicalComparison of a literal number and a number range should work correctly", function()
	assert(LNumber(20):LogicalComparison(LNumberRange(0, 10), ">") == true)
	assert(LNumber(5):LogicalComparison(LNumberRange(0, 10), "<") == nil) -- Indeterminate
	assert(LNumber(15):LogicalComparison(LNumberRange(0, 10), "==") == false)
end)

test("BinaryOperator should work correctly for literal numbers", function()
	assert(LNumber(5):BinaryOperator(LNumber(3), "+"):GetData() == 8)
	assert(LNumber(10):BinaryOperator(LNumber(2), "*"):GetData() == 20)
	assert(LNumber(15):BinaryOperator(LNumber(3), "/"):GetData() == 5)
end)

test("PrefixOperator should work correctly for literal numbers", function()
	assert(LNumber(5):PrefixOperator("-"):GetData() == -5)
	assert(LNumber(5):PrefixOperator("~"):GetData() == -6) -- Bitwise NOT
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
	assert(LNumber(0):LogicalComparison(LNumber(1), "<") == true)
	assert(LNumber(0):LogicalComparison(LNumber(-1), ">") == true)
end)

test("Non-integer numbers should work correctly", function()
	assert(LNumber(3.14):IsSubsetOf(LNumberRange(3, 4)))
	assert(LNumber(2.5):BinaryOperator(LNumber(1.5), "+"):GetData() == 4)
end)

-- Helper function to check if two ranges are equal
local function rangesEqual(range1, range2)
	return range1:GetData() == range2:GetData() and
		range1:GetMaxLiteral() == range2:GetMaxLiteral()
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
	assert(rangesEqual(result, LNumberRange(5, 5)))
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
	assert(rangesEqual(result, LNumberRange(0, 0)))
end)

test("Arithmetic with infinite ranges", function()
	local positiveInf = LNumberRange(0, math.huge)
	local negativeInf = LNumberRange(-math.huge, 0)
	local result = positiveInf:BinaryOperator(negativeInf, "+")
	assert(rangesEqual(result, LNumberRange(-math.huge, math.huge)))
end)

do
	local max = math.max
	local min = math.min

	local function brute_force(a_min, a_max, operator, b_min, b_max)
		local a_res_min
		local a_res_max
		local b_res_min
		local b_res_max
		local func = loadstring("local a, b = ... return a " .. operator .. " b")

		for x = a_min, a_max do
			for y = b_min, b_max do
				if func(x, y) then
					if not a_res_min then
						a_res_min = x
					else
						a_res_min = min(a_res_min, x)
					end

					if not a_res_max then
						a_res_max = x
					else
						a_res_max = max(a_res_max, x)
					end
				else
					if not b_res_min then
						b_res_min = y
					else
						b_res_min = min(b_res_min, y)
					end

					if not b_res_max then
						b_res_max = y
					else
						b_res_max = max(b_res_max, y)
					end
				end
			end
		end

		return a_res_min, a_res_max, b_res_min, b_res_max
	end

	local function range_tostring(a_min, a_max, b_min, b_max)
		return tostring(a_min) .. ".." .. tostring(a_max) .. ", " .. tostring(b_min) .. ".." .. tostring(b_max)
	end

	local LNumberRange = require("nattlua.types.number").LNumberRange

	local function intersect(a_min, a_max, op, b_min, b_max)
		local a = LNumberRange(a_min, a_max)
		local b = LNumberRange(b_min, b_max)
		local x, y = a.IntersectComparison(a, b, op)
		return x and x:GetMinLiteral(),
		x and x:GetMaxLiteral() or x and x:GetMinLiteral() or nil,
		y and y:GetMinLiteral(),
		y and y:GetMaxLiteral() or y and y:GetMinLiteral() or nil
	end

	local function check(a_min, a_max, op, b_min, b_max)
		local expect = range_tostring(brute_force(a_min, a_max, op, b_min, b_max))
		local result = range_tostring(intersect(a_min, a_max, op, b_min, b_max))

		do
			local input = range_tostring(a_min, a_max, b_min, b_max):gsub(", ", " " .. op .. " ")

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
						check(x, y, op, z, w)
					end
				end
			end
		end
	end
end