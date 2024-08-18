local LString = require("nattlua.types.string").LString
local Union = require("nattlua.types.union").Union
local cast = require("nattlua.analyzer.cast")

-- boolean is a union
assert(
	Union(cast{true, false}):Equal(analyze("local a: boolean"):GetLocalOrGlobalValue(LString("a")))
)
-- boolean is truthy and falsy
local a = analyze("local a: boolean")
equal(true, a:GetLocalOrGlobalValue(LString("a")):IsTruthy())
equal(true, a:GetLocalOrGlobalValue(LString("a")):IsFalsy())
