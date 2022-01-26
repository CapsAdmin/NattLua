local T = require("test.helpers")
local run = T.RunCode
local transpile = T.Transpile

run[[
    local i = 1

    while true do
        i = i + 1
        if i >= 10 then break end
    end

    attest.equal(i, 10)
]]

run[[
    local i = 1 as number
    local o = 1

    while true do
        o = o + 1
        i = i + 1
        if i >= 10 then break end
    end

    attest.equal(o, 2) -- this should probably be number too as it's incremented in an uncertain loop
]]

run[[
    local a = 1
    repeat
        attest.equal(a, 1)
    until false
]]

run[[
    local a = 0
    while false do
        a = 1
    end
    attest.equal(a, 0)
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

run[[

    local a = 0
    while _ as boolean do
        a = a + 1
    end
    attest.equal(a, _ as number)

]]

run[[
    local x: nil | 1

    while x ~= nil do
        attest.equal(x, 1)
        x = x + 1
        attest.equal(x, _ as number)
        attest.equal(x>10, _ as true | false)
        if x > 10 then break end
    end
]]