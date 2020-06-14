local T = require("spec.lua.typesystem_helpers")
local N = T.Number
local Object = T.Object

describe("numbers", function()
    local any = Object("any")

    local _42 = Object("number", 42, true)
    local all_numbers = Object("number")

    local _32_to_52 = Object("number", 32, true)
    _32_to_52.max = Object("number", 52, true)

    it("a literal number should be contained within all numbers", function()
        assert(_42:ContainedIn(all_numbers))
    end)

    it("all numbers should not be contained within a literal number", function()
        assert(not all_numbers:ContainedIn(_42))
    end)

    it("42 should be contained within any", function()
        assert(_42:ContainedIn(any))
    end)

    it("any should be contained within 42", function()
        assert(any:ContainedIn(_42))
    end)

    it("42 should be contained within 32..52", function()
        assert(_42:ContainedIn(_32_to_52))
    end)

    it("32..52 should not be contained within 42", function()
        assert(not _32_to_52:ContainedIn(_42))
    end)
end)