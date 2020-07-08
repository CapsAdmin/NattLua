local T = require("test.helpers")
local run = T.RunCode

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
