local T = require("test.helpers")
local Object = T.Object

local any = T.Any()

local foo = T.String("foo")
local all_letters = T.String()
local foo_bar = T.String("foo bar")

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
