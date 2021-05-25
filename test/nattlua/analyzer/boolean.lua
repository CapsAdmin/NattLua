local T = require("test.helpers")
local run = T.RunCode
local String = T.String

test("boolean is a union", function()
    assert(T.Union(true, false):Equal(run("local a: boolean"):GetLocalOrEnvironmentValue(String("a"), "runtime")))
end)

test("boolean is truthy and falsy", function()
    local a = run("local a: boolean")
    equal(true, a:GetLocalOrEnvironmentValue(String("a")):IsTruthy())
    equal(true, a:GetLocalOrEnvironmentValue(String("a")):IsFalsy())
end)
