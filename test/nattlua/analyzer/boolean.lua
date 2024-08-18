local T = require("test.helpers")
local analyze = T.RunCode
local LString = require("nattlua.types.string").LString
-- boolean is a union
assert(
	T.Union(true, false):Equal(analyze("local a: boolean"):GetLocalOrGlobalValue(LString("a")))
)
-- boolean is truthy and falsy
local a = analyze("local a: boolean")
equal(true, a:GetLocalOrGlobalValue(LString("a")):IsTruthy())
equal(true, a:GetLocalOrGlobalValue(LString("a")):IsFalsy())
