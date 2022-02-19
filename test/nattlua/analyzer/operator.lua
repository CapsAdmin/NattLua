local T = require("test.helpers")
local run = T.RunCode

test("prefix", function()
	run([[
        local a = 1
        a = -a
        attest.equal(a, -1)
    ]])
end)

test("postfix", function()
	run([[
        local a = 1++
        attest.equal(a, 2)
    ]])
end)
