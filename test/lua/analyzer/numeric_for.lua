local T = require("test.helpers")
local run = T.RunCode

test("for i = 1, 10", function()
    run[[
        for i = 1, 10 do
            type_assert(i, _ as 1 .. 10)
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
    --  1, number is not the same as 1, inf because if the max
    -- value is below 1 it will not execute

    -- so either the scope runs with number, or not at all
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