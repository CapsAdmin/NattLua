local Union = require("nattlua.types.union")
local True = require("nattlua.types.symbol").True
local False = require("nattlua.types.symbol").False
local Boolean = require("nattlua.types.union").Boolean
local shared = require("nattlua.types.shared")

test(tostring(True()) .. " should be a subset of " .. tostring(Boolean()), function()
	assert(shared.IsSubsetOf(True(), Boolean()))
end)

test(tostring(False()) .. "  should be a subset of " .. tostring(Boolean()), function()
	assert(shared.IsSubsetOf(False(), Boolean()))
end)

test(tostring(Boolean()) .. " is NOT a subset of " .. tostring(True()), function()
	assert(not shared.IsSubsetOf(Boolean(), True()))
end)

test(tostring(Boolean()) .. " is NOT a subset of " .. tostring(False()), function()
	assert(not shared.IsSubsetOf(Boolean(), False()))
end)