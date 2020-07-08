local T = require("test.helpers")
local Function = T.Function
local Number = T.Number
local String = T.String
local Symbol = T.Symbol
local Set = T.Set
local Tuple = T.Tuple

local overloads = Set(Function({
    arg = Tuple(Number(), String()),
    ret = Tuple(Symbol("ROFL")),
}), Function({
    arg = Tuple(String(), Number()),
    ret = Tuple(Symbol("LOL")),
}))

it("overload should work", function()
    local a = require("oh.lua.analyzer")()
    assert(assert(a:Call(overloads, Tuple(String(), Number()))):Get(1):GetData() == "LOL")
    assert(assert(a:Call(overloads, Tuple(Number(5), String()))):Get(1):GetData() == "ROFL")
end)
