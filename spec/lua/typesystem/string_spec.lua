local T = require("spec.lua.helpers")
local Object = T.Object

describe("strings", function()
    local any = Object("any")

    local foo = Object("string", "foo", true)
    local all_letters = Object("string")
    local foo_bar = Object("string", "foo bar", true)

    it("'foo' should be contained within all letters", function()
        assert(foo:SubsetOf(all_letters))
    end)

    it("all letters should not be contained within 'foo'", function()
        assert(not all_letters:SubsetOf(foo))
    end)

    it("'foo' should be contained in any", function()
        assert(foo:SubsetOf(any))
    end)

    it("any should be contained within 'foo'", function()
        assert(any:SubsetOf(foo))
    end)
end)