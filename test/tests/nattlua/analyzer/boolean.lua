local LString = require("nattlua.types.string").LString
local Union = require("nattlua.types.union").Union
local cast = require("nattlua.analyzer.cast")
local shared = require("nattlua.types.shared")
local a = analyze("local a: boolean")
-- boolean is a union
assert(shared.Equal(Union(cast({true, false})), a:GetLocalOrGlobalValue(LString("a"))))
-- boolean is truthy and falsy
equal(true, a:GetLocalOrGlobalValue(LString("a")):IsTruthy())
equal(true, a:GetLocalOrGlobalValue(LString("a")):IsFalsy())