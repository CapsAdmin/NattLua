local T = require("test.helpers")
local run = T.RunCode

test("boolean is a set", function()
    equal(T.Set(true, false):GetSignature(), run("local a: boolean"):GetEnvironmentValue("a", "runtime"):GetSignature())
end)

test("boolean is truthy and falsy", function()
    local a = run("local a: boolean")
    equal(true, a:GetEnvironmentValue("a"):IsTruthy())
    equal(true, a:GetEnvironmentValue("a"):IsFalsy())
end)
