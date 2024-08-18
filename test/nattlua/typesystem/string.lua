local LString = require("nattlua.types.string").LString
local String = require("nattlua.types.string").String
local Any = require("nattlua.types.any").Any

local any = Any()
local foo = LString("foo")
local all_letters = String()
local foo_bar = LString("foo bar")

test("'foo' should be contained within all letters", function()
	assert(foo:IsSubsetOf(all_letters))
end)

test("all letters should not be contained within 'foo'", function()
	assert(not all_letters:IsSubsetOf(foo))
end)

test("'foo' should be contained in any", function()
	assert(foo:IsSubsetOf(any))
end)

test("any should be contained within 'foo'", function()
	assert(any:IsSubsetOf(foo))
end)