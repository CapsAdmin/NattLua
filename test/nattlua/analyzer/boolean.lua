local T = require("test.helpers")
local run = T.RunCode

test("boolean is a union", function()
    assert(T.Union(true, false):Equal(run("local a: boolean"):GetLocalOrEnvironmentValue(types.Literal("a"), "runtime")))
end)

test("boolean is truthy and falsy", function()
    local a = run("local a: boolean")
    equal(true, a:GetLocalOrEnvironmentValue(types.Literal("a")):IsTruthy())
    equal(true, a:GetLocalOrEnvironmentValue(types.Literal("a")):IsFalsy())
end)
