local T = require("spec.lua.helpers")
local O = T.Object
local N = T.Number
local Set = T.Set
local Tuple = T.Tuple

describe("function", function()
    local overloads = Set(O("function", {
        arg = Tuple(O"number", O"string"),
        ret = Tuple(O"ROFL"),
    }), O("function", {
        arg = Tuple(O"string", O"number"),
        ret = Tuple(O"LOL"),
    }))

    it("overload should work", function()
        local a = require("oh.lua.analyzer")()
        assert(assert(a:CallOperator(overloads, Tuple(O"string", O"number"))):GetSignature() == "LOL")
        assert(assert(a:CallOperator(overloads, Tuple(N(5), O"string"))):GetSignature() == "ROFL")
    end)
end)