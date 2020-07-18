local T = require("test.helpers")
local String = T.String
local Number = T.Number
local Tuple = T.Tuple

local SN = Tuple(String(), Number())
local NS = Tuple(Number(), String())
local SNS = Tuple(String(), Number(), String())

test(tostring(SN) .. " should not be a subset of " .. tostring(NS), function()
    assert(not SN:SubsetOf(NS))
end)

test(tostring(SN) .. " should be a subset of " .. tostring(SN), function()
    assert(SN:SubsetOf(SN))
end)

test(tostring(SN) .. " should be a subset of " .. tostring(SNS), function()
    assert(SN:SubsetOf(SNS))
end)

test(tostring(SNS) .. " should not be a subset of " .. tostring(SN), function()
    assert(not SNS:SubsetOf(SN))
end)
