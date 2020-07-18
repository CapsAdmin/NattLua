local T = require("test.helpers")
local run = T.RunCode

local check = function(analyzer, to)
    equal(to:gsub("%s+", " "), tostring(analyzer:GetValue("a", "runtime")):gsub("%s+", " "))
end


test("can be simple", function()
    run[[
        local x = {1, 2, 3}
        x[2] = 10

        type_assert(x[2], 10)
    ]]
end)

test("can be sparse", function()
    run[[
        local x = {
            [2] = 2,
            [10] = 3,
        }

        type_assert(x[10], 3)
    ]]
end)

test("can be indirect", function()
    run[[
        local RED = 1
        local BLUE = 2
        local x = {
            [RED] = 2,
            [BLUE] = 3,
        }
        type_assert(x[RED], 2)
    ]]
end)

test("indirect only works for numeric keys", function()
    run[[
        local RED = 1
        local BLUE = 2
        local GREEN: string = (function():string return "hello" end)()
        local x = {
            [RED] = 2,
            [BLUE] = 3,
            [GREEN] = 4,
        }
        type_assert(x[GREEN], _ as 4 | nil)
    ]]
    run([[
        local RED = 1
        local BLUE = 2
        local GREEN: string = (function():string return "hello" end)()

        local x: {[1 .. inf] = number} = {
            [RED] = 2,
            [BLUE] = 3,
            [GREEN] = 4,
        }
    ]], "hello.- is not the same type as 1%.%.inf")
end)

test("indirect works array-records", function()
    run[[
        local tbl = {}
        for i = 1, 100 do
            tbl[i] = i*100
        end
        tbl[50] = true
        type_assert(tbl[20], _ as 100 .. 10000 | true)
    ]]
end)

test("{[number]: any}", function()
    check(run[[local a: {[number] = any} = {[1] = 1}]], "{ number ⊃ number(1) = any ⊃ number(1) }")
    run([[local a: {[number] = any} = {foo = 1}]], [[is not the same type as number]])
end)


test("{[1 .. inf]: any}", function()
    check(run[[local a: {[1 .. inf] = any} = {[1234] = 1}]], "{ 1..inf ⊃ 1234 = any ⊃ number(1) }")

    run([[local a: {[1 .. inf] = any} = {[-1234] = 1}]], [[%-1234 is not a subset of 1%.%.inf]])
end)

test("traditional array", function()
    run[[
        local function Array<(T: any, L: number)>
            return {[1 .. L] = T}
        end

        local list: Array<(number, 3)> = {1, 2, 3}
    ]]

    run([[
        local function Array<(T: any, L: number)>
            return {[1 .. L] = T}
        end

        local list: Array<(number, 3)> = {1, 2, 3, 4}
    ]], "4 is not a subset of 1%.%.3")
end)
