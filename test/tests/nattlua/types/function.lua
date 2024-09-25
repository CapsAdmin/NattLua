local Function = require("nattlua.types.function").Function
local Number = require("nattlua.types.number").Number
local LNumber = require("nattlua.types.number").LNumber
local String = require("nattlua.types.string").String
local Symbol = require("nattlua.types.symbol").Symbol
local Union = require("nattlua.types.union").Union
local Tuple = require("nattlua.types.tuple").Tuple
local cast = require("nattlua.analyzer.cast")
local overloads = Union(
	{
		Function(Tuple({Number(), String()}), Tuple({Symbol("ROFL")})),
		Function(Tuple({String(), Number()}), Tuple({Symbol("LOL")})),
	}
)

test("overload", function()
	local a = require("nattlua.analyzer").New()
	assert(
		assert(a:Call(overloads, Tuple(cast({String(), Number()})))):Get(1):GetData() == "LOL"
	)
	assert(
		assert(a:Call(overloads, Tuple(cast({LNumber(5), String()})))):Get(1):GetData() == "ROFL"
	)
end)
