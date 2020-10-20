local T = require("test.helpers")
local run = T.RunCode

test("meta library", function()
    run[[
        local a = "1234"
        type_assert(string.len(a), 4)
        type_assert(a:len(), 4)
    ]]
end)

test("patterns", function()
    run[[
        local a: $"FOO_.-" = "FOO_BAR"
    ]]

    run([[
        local a: $"FOO_.-" = "lol"
    ]], "the pattern failed to match")
end)
