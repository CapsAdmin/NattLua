local T = require("test.helpers")
local run = T.RunCode
local transpile = T.Transpile

run[[
    local i = 1

    while true do
        i = i + 1
        if i >= 10 then break end
    end

    types.assert(i, 10)
]]

run[[
    local i = 1 as number
    local o = 1

    while true do
        o = o + 1
        i = i + 1
        if i >= 10 then break end
    end

    types.assert(o, 2) -- this should probably be number too as it's incremented in an uncertain loop
]]

run[[
    local a = 1
    repeat
        types.assert(a, 1)
    until false
]]

run[[
    local a = 0
    while false do
        a = 1
    end
    types.assert(a, 0)
]]

run[[
    local a = 1
    while true do
        a = a + 1
        break
    end
    local b = a

    repeat
        b = b + 1
    until true

    local c = b
]]