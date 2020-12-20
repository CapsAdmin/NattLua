local T = require("test.helpers")
local run = T.RunCode
local transpile = T.Transpile
test("for i = 1, 10000", function()
    run[[
        for i = 1, 10000 do
            type_assert(i, _ as 1 .. 10000)
        end
    ]]
end)

test("for i = 1, number", function()
    run[[
        for i = 1, _ as number do
            type_assert(i, _ as number)
        end
    ]]
end)

test("for i = 1, number is an uncertain scope", function()
    run[[
        local a = 0
        for i = 1, _ as number do
            type_assert(i, _ as number)
            a = 1
        end
        type_assert(a, _ as 1 | 0)
    ]]
end)

pending("uncertain numeric for loop arithmetic", function()
    run[[
        local a = 0
        for i = 1, _ as number do
            a = a + 1
        end
        type_assert(a, _ as number) -- we could say that a+=1 would make a 1 .. inf but not sure if it's worth it
    ]]
end)


do
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

    assert(code:find("i: 1 | 2 = 1", nil, true) ~= nil)
    assert(code:find("local a: false | true = x", nil, true) ~= nil)
    assert(code:find("local b: false = x", nil, true) ~= nil)
end

run[[
    local lol = 0

    for i = 1, 5 do
        if i == 3 then
            break
        end
        
        lol = lol + 1

        if i == 3 then
            type_assert("should never reach")
        end
    end

    type_assert(lol, 2)
]]
