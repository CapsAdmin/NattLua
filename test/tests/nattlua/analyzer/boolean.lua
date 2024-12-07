local LString = require("nattlua.types.string").LString
local Union = require("nattlua.types.union").Union
local cast = require("nattlua.analyzer.cast")
local a = analyze("local a: boolean")
-- boolean is a union
assert(Union(cast({true, false})):Equal(a:GetLocalOrGlobalValue(LString("a"))))
-- boolean is truthy and falsy
equal(true, a:GetLocalOrGlobalValue(LString("a")):IsTruthy())
equal(true, a:GetLocalOrGlobalValue(LString("a")):IsFalsy())
