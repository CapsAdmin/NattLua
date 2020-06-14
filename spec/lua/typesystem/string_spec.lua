local T = require("spec.lua.typesystem_helpers")
local Object = T.Object

describe("strings", function()
    local any = Object("any")

    local foo = Object("string", "foo", true)
    local all_letters = Object("string")
    local foo_bar = Object("string", "foo bar", true)

    it("a literal string should be contained within all letters", function()
        assert(foo:ContainedIn(all_letters))
    end)

    it("all numbers should not be contained within a literal number", function()
        assert(not all_letters:ContainedIn(foo))
    end)

    it("42 should be contained within any", function()
        assert(foo:ContainedIn(any))
    end)

    it("any should be contained within 42", function()
        assert(any:ContainedIn(foo))
    end)
end)