local T = require("spec.lua.helpers")
local O = T.Object
local Tuple = T.Tuple

local SN = Tuple(O"string", O"number")
local NS = Tuple(O"number", O"string")
local SNS = Tuple(O"string", O"number", O"string")

describe("tuple", function()
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
end)