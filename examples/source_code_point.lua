local print_util = require("oh.print_util")

local code = [[
for i = 1, #code do
    local char = code:sub(i, i)

    if char == "dd" then
        start = i+1
    end

    if char == "cc" then
        start = i+1
    end

    local foo = >[[
        Lorem Ipsum
        Foo Bar
        Thy Thee
        End Of
    ]<

    if char == "aaa" then
        stop = i-1
        break
    end

    if char == "bbb" then
        stop = i-1
        break
    end
end
]]

local function example(code)
    local start
    for i = 1, #code do
        if code:sub(i, i) == ">" then start = i+1 end
        if code:sub(i, i) == "<" then return start, i-1 end
    end
end
local start, stop = example(code)

print(print_util.FormatError(code, "format_error.lua", "unterminated multiline string", start, stop))
