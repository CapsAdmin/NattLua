local T = require("spec.lua.helpers")
local run = T.RunCode

describe("string", function()
    it("meta library should work", function()
        run[[
            local a = "1234"
            type_assert(string.len(a), 4)
            type_assert(a:len(), 4)
        ]]
    end)
end)