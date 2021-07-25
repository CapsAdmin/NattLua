local T = require("test.helpers")
local run = T.RunCode

test("meta library", function()
    run[[
        local a = "1234"
        types.assert(string.len(a), 4)
        types.assert(a:len(), 4)
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
    
    types.assert(foo, "foo")
    types.assert(bar, "foo")
    types.assert(faz, "foo")
]===]
