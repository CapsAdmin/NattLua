local T = require("spec.lua.helpers")
local Set = T.Set
local Tuple = T.Tuple
local O = T.Object

describe("typesystem", function()
    it("a set should not contain duplicates", function()
        assert.equal(Set("a", "b", "a", "a"):Serialize(), Set("a", "b"):Serialize())
    end)

    local larger = Set("a", "b", "c")
    local smaller = Set("a", "b")
    local different = Set("b", "x", "y")

    it("a set should be a subset of an identical set", function()
        assert(smaller:SubsetOf(smaller))
    end)

    it("a smaller set should be a subset of a larger set", function()
        assert(smaller:SubsetOf(larger))
    end)

    it("a larger set should not be a subset of a smaller set", function()
        assert(not larger:SubsetOf(smaller))
    end)

    it("a different set should not be a subset of a set", function()
        assert(not different:SubsetOf(larger))
    end)

    it("a larger set should not be a subset of a different set", function()
        assert(not larger:SubsetOf(different))
    end)

    it("a tuple of one smaller set should be a subset of a larger set", function()
        assert(Tuple(smaller):SubsetOf(larger))
    end)

    it("a smaller set should be a subset of a tuple containing 1 larger set", function()
        assert(smaller:SubsetOf(Tuple(larger)))
    end)

    it("a number should be a subset of a set with numbers", function()
        assert(O("number", 24, true)):SubsetOf(Set(O("number"), O("number")))
    end)

    it("a smaller set within an empty set should be identical to the smaller set", function()
        assert.equal(smaller:Serialize(), Set(smaller):Serialize())
    end)

    it("a set containing one number literal should be a subset of a set containing a number", function()
        assert(Set(1):SubsetOf(O("number"), O("string")))
    end)

    local A = Set(1, 4, 5, 9, 13)
    local B = Set(2, 5, 6, 8, 9)
    local expected = Set(5, 9)

    it(tostring(A) ..  " intersected with " .. tostring(B) .. " should result in " .. tostring(expected), function()
        assert.equal(A:Intersect(B):GetSignature(), expected:GetSignature())
    end)

    local A = Set(1, 2, 3)
    local B = Set(1, 2, 3, 4)

    it(tostring(B) .. " should equal the union of " .. tostring(A) .. " and " .. tostring(B), function()
        assert.equal(B:GetSignature(), A:Union(B):GetSignature())
        assert.equal(4, B:GetLength())
        assert(A:SubsetOf(B))
    end)
end)