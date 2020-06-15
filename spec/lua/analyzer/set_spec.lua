local T = require("spec.lua.helpers")
local run = T.RunCode

describe("set", function()
    it("should work", function()
        local a = run[[local type a = 1337 | 8888]]:GetValue("a", "typesystem")
        assert.equal(2, a:GetLength())
        assert.equal(1337, a:GetElements()[1].data)
        assert.equal(8888, a:GetElements()[2].data)
    end)

    it("union operator should work", function()
        local a = run[[
            local type a = 1337 | 888
            local type b = 666 | 777
            local type c = a | b
        ]]:GetValue("c", "typesystem")
        assert.equal(4, a:GetLength())
    end)
end)