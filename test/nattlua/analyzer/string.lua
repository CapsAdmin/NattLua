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


run[=[
    local fixed = {
        "a", "b", "f", "n", "r", "t", "v", "\\", "\"", "'",
    }
    local pattern = "\\[" .. table.concat(fixed, "\\") .. "]"

    local map_double_quote = {[ [[\"]] ] = [["]]}
    local map_single_quote = {[ [[\']] ] = [[']]}

    for _, v in ipairs(fixed) do
        map_double_quote["\\" .. v] = load("return \"\\" .. v .. "\"")()
        map_single_quote["\\" .. v] = load("return \"\\" .. v .. "\"")()
    end

    local function reverse_escape_string(str, quote)
        if quote == "\"" then
            str = str:gsub(pattern, map_double_quote)
        elseif quote == "'" then
            str = str:gsub(pattern, map_single_quote)
        end
        return str
    end

    types.assert(reverse_escape_string("hello\\nworld", "\""), "hello\nworld")
]=]