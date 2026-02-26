local LString = require("nattlua.types.string").LString
local String = require("nattlua.types.string").String
local Any = require("nattlua.types.any").Any
local shared = require("nattlua.types.shared")
local any = Any()
local foo = LString("foo")
local all_letters = String()
local foo_bar = LString("foo bar")

test("'foo' should be contained within all letters", function()
	assert(shared.IsSubsetOf(foo, all_letters))
end)

test("all letters should not be contained within 'foo'", function()
	assert(not shared.IsSubsetOf(all_letters, foo))
end)

test("'foo' should be contained in any", function()
	assert(shared.IsSubsetOf(foo, any))
end)

test("any should be contained within 'foo'", function()
	assert(shared.IsSubsetOf(any, foo))
end)