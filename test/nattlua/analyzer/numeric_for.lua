local T = require("test.helpers")
local run = T.RunCode
local transpile = T.Transpile
run[[
    for i = 1, 10000 do
        types.assert(i, _ as 1 .. 10000)
    end
]]

run[[
    for i = 1, _ as number do
        types.assert(i, _ as 1..inf)
    end
]]

pending[[
    --for i = 1, number is an uncertain scope
    local a = 0
    for i = 1, _ as number do
        types.assert(i, _ as number)
        a = 1
    end
    types.assert(a, _ as number)
]]

pending[[
    local a = 0
    for i = 1, _ as number do
        a = a + 1
    end
    types.assert(a, _ as number) -- we could say that a+=1 would make a 1 .. inf but not sure if it's worth it
]]

pending("annotation", function() 
    local code = transpile([[
        local x
        for i = 1, 2 do -- i should be 1 | 2
            x = i == 1 -- x should be true | false
            local a = x -- x should be true | false 
            -- because from the users point of view x is both x = 1 == 1 and x = 2 == 1 at the same time
        end
        -- x should be false, because i == 2 is the last statement
        local b = x
    ]])
        
    assert(code:find("i--[[#:1 | 2]] = 1", nil, true) ~= nil)
    -- if the union sorting algorithm changes, we probably need to change this
    assert(code:find("local a--[[#:false | true]] = x", nil, true) ~= nil)
    assert(code:find("local b--[[#:false]] = x", nil, true) ~= nil)
end)

run[[
    local lol = 0

    for i = 1, 5 do
        if i == 3 then
            break
        end
        
        lol = lol + 1

        if i == 3 then
            types.assert("should never reach")
        end
    end

    types.assert(lol, 2)
]]


pending[[
    for i = 1, 3 do
        -- i is number if max is math.huge for example
    
        local x = ("lol"):byte(1,1 as 1 | 0) -- we do 1 | 0 because 0 will make :byte return nil and 108 (l)
        -- becomes number | nil
        --print(x, i)
        if not x then
            error("lol")
        end
        local y = x
        -- when ran as merged scope error("lol") doesn't return properly
    
        types.assert(x, 108)
        types.assert_superset(i, _ as 1 | 2 | 3)
    end
]]

run[[
    local string_byte = string.byte
    local x = 0
    local check = false
    for i = 1, 10 do
        x = x + i
        types.assert(string_byte, string.byte)
        
        if check then
            types.assert(i, _ as 1 | 10 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9)
        end
        
        if i == 10 then
            check = true
        end
    end
    types.assert(x,55)
]]

run[[
    local tbl = {}
    for i = 1, 10000 do
        tbl[i] = i*100
    end
    tbl[50] = true
    types.assert(tbl[20], _ as (100..1000000) | true)
]]
