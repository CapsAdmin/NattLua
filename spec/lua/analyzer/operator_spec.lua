local T = require("spec.lua.helpers")
local run = T.RunCode

describe("operators", function()
    it("prefix", function()
        run([[
            local a = 1
            a = -a
            type_assert(a, -1)
        ]])
    end)

    it("postfix", function()
        run([[
            local a = 1++
            type_assert(a, 2)
        ]])
    end)
end)