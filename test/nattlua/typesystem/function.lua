local T = require("test.helpers")
local Function = T.Function
local Number = T.Number
local String = T.String
local Symbol = T.Symbol
local Union = T.Union
local Tuple = T.Tuple
local overloads = Union(
	Function(Tuple(Number(), String()), Tuple(Symbol("ROFL"))),
	Function(Tuple(String(), Number()), Tuple(Symbol("LOL")))
)

test("overload", function()
	local a = require("nattlua.analyzer").New()
	assert(assert(overloads:Call(a, Tuple(String(), Number()))):Get(1):GetData() == "LOL")
	assert(assert(overloads:Call(a, Tuple(Number(5), String()))):Get(1):GetData() == "ROFL")
end)
