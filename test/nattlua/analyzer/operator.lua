local T = require("test.helpers")
local run = T.RunCode

test("prefix", function()
    run([[
        local a = 1
        a = -a
        types.assert(a, -1)
    ]])
end)

test("postfix", function()
    run([[
        local a = 1++
        types.assert(a, 2)
    ]])
end)
