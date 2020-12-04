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
    ]], "cannot find .- in pattern")
end)

run[===[
    local foo = [[foo]]
    local bar = [=[foo]=]
    local faz = [==[foo]==]
    
    type_assert(foo, "foo")
    type_assert(bar, "foo")
    type_assert(faz, "foo")
]===]