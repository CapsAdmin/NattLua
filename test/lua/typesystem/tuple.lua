local T = require("test.helpers")
local String = T.String
local Number = T.Number
local Tuple = T.Tuple

local SN = Tuple(String(), Number())
local NS = Tuple(Number(), String())
local SNS = Tuple(String(), Number(), String())

it(tostring(SN) .. " should not be a subset of " .. tostring(NS), function()
    assert(not SN:SubsetOf(NS))
end)

it(tostring(SN) .. " should be a subset of " .. tostring(SN), function()
    assert(SN:SubsetOf(SN))
end)

it(tostring(SN) .. " should be a subset of " .. tostring(SNS), function()
    assert(SN:SubsetOf(SNS))
end)

it(tostring(SNS) .. " should not be a subset of " .. tostring(SN), function()
    assert(not SNS:SubsetOf(SN))
end)
