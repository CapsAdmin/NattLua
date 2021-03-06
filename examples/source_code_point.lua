local helpers = require("nattlua.other.helpers")
local code = [==[
for i = 1, #code do
    local char = code:sub(i, i)

    if char == "dd" then
        start = i+1
    end

    if char == "cc" then
        start = i+2
    end

    local foo = >[[
        Lorem Ipsum
        Foo Bar
        Thy Thee
        End Of
    ]]<

    if char == "aaa" then
        stop = i-1
        break
    end

    if char == "bbb" then
        stop = i-1
        break
    end
end
]==]

local function example(code)
    local start
    for i = 1, #code do
        if code:sub(i, i) == ">" then start = i+1 end
        if code:sub(i, i) == "<" then return start, i-1 end
    end
end
local start, stop = example(code)

print(helpers.FormatError(code, "format_error.lua", "pointing at this multiline string", start, stop))
