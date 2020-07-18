local T = require("test.helpers")
local Set = T.Set
local String = T.String
local Number = T.Number
local Tuple = T.Tuple

test("a set should not contain duplicates", function()
    equal(Set("a", "b", "a", "a"):GetSignature(), Set("a", "b"):GetSignature())
end)

local larger = Set("a", "b", "c")
local smaller = Set("a", "b")
local different = Set("b", "x", "y")

test("a set should be a subset of an identical set", function()
    assert(smaller:SubsetOf(smaller))
end)

test("a smaller set should be a subset of a larger set", function()
    assert(smaller:SubsetOf(larger))
end)

test("a larger set should not be a subset of a smaller set", function()
    assert(not larger:SubsetOf(smaller))
end)

test("a different set should not be a subset of a set", function()
    assert(not different:SubsetOf(larger))
end)

test("a larger set should not be a subset of a different set", function()
    assert(not larger:SubsetOf(different))
end)

test("a tuple of one smaller set should be a subset of a larger set", function()
    assert(Tuple(smaller):SubsetOf(larger))
end)

test("a smaller set should be a subset of a tuple containing 1 larger set", function()
    assert(smaller:SubsetOf(Tuple(larger)))
end)

test("a number should be a subset of a set with numbers", function()
    assert(Number(24)):SubsetOf(Set(Number(), Number()))
end)

test("a smaller set within an empty set should be identical to the smaller set", function()
    equal(smaller:GetSignature(), Set(smaller):GetSignature())
end)

test("a set containing one literal number should be a subset of a set containing a number", function()
    assert(Set(1):SubsetOf(Number()))
end)

local A = Set(1, 4, 5, 9, 13)
local B = Set(2, 5, 6, 8, 9)
local expected = Set(5, 9)

test(tostring(A) ..  " intersected with " .. tostring(B) .. " should result in " .. tostring(expected), function()
    equal(A:Intersect(B):GetSignature(), expected:GetSignature())
end)

local A = Set(1, 2, 3)
local B = Set(1, 2, 3, 4)

test(tostring(B) .. " should equal the union of " .. tostring(A) .. " and " .. tostring(B), function()
    equal(B:GetSignature(), A:Union(B):GetSignature())
    equal(4, B:GetLength())
    assert(A:SubsetOf(B))
end)