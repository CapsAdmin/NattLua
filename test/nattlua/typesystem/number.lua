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