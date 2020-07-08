local T = require("test.helpers")
local N = T.Number
local Symbol = T.Number
local Set = T.Set

local yes = Symbol(true)
local no = Symbol(false)
local yes_and_no =  Set(yes, no)

it(tostring(yes) .. " should be a subset of " .. tostring(yes_and_no), function()
    assert(yes:SubsetOf(yes_and_no))
end)

it(tostring(no) .. "  should be a subset of " .. tostring(yes_and_no), function()
    assert(no:SubsetOf(yes_and_no))
end)

it(tostring(yes_and_no) .. " is NOT a subset of " .. tostring(yes), function()
    assert(not yes_and_no:SubsetOf(yes))
end)

it(tostring(yes_and_no) .. " is NOT a subset of " .. tostring(no), function()
    assert(not yes_and_no:SubsetOf(no))
end)
