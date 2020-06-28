local T = require("spec.lua.helpers")
local run = T.RunCode

describe("boolean", function()
    it("boolean is a set", function()
        assert.equal(T.Set(true, false):GetSignature(), run("local a: boolean"):GetValue("a", "runtime"):GetSignature())
    end)
    it("boolean is truthy and falsy", function()
        local a = run("local a: boolean")
        assert.equal(true, a:GetValue("a"):IsTruthy())
        assert.equal(true, a:GetValue("a"):IsFalsy())
    end)
end)