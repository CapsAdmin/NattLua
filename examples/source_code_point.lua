local oh = require("oh.oh")

local function example(code)
    local start, stop

    for i = 1, #code do
        local char = code:sub(i, i)
        
        if char == ">" then
            start = i+1
        end
        
        if char == "<" then
            stop = i-1
            break
        end
    end

    return start, stop
end
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
local start, stop = example(code)

print(oh.FormatError(code, "format_error.lua", "unterminated multiline string", start, stop))
