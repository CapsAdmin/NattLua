local Union = require("nattlua.types.union")
local True = require("nattlua.types.symbol").True
local False = require("nattlua.types.symbol").False
local Boolean = require("nattlua.types.union").Boolean

test(tostring(True()) .. " should be a subset of " .. tostring(Boolean()), function()
	assert(True():IsSubsetOf(Boolean()))
end)

test(tostring(False()) .. "  should be a subset of " .. tostring(Boolean()), function()
	assert(False():IsSubsetOf(Boolean()))
end)

test(tostring(Boolean()) .. " is NOT a subset of " .. tostring(True()), function()
	assert(not Boolean():IsSubsetOf(True()))
end)

test(tostring(Boolean()) .. " is NOT a subset of " .. tostring(False()), function()
	assert(not Boolean():IsSubsetOf(False()))
end)