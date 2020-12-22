local T = require("test.helpers")
local run = T.RunCode

local check = function(analyzer, to)
    equal(to:gsub("%s+", " "), tostring(analyzer:GetLocalOrEnvironmentValue("a", "runtime")):gsub("%s+", " "), 2)
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
        local GREEN: string
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
        local GREEN: string
        local x: {[1 .. inf] = number} = {
            [RED] = 2,
            [BLUE] = 3,
            [GREEN] = 4,
        }
    ]], "has no field string")
end)

test("indirect works array-records", function()
    run[[
        local tbl = {}
        for i = 1, 10000 do
            tbl[i] = i*100
        end
        tbl[50] = true
        type_assert(tbl[20], _ as 100 .. 1000000 | true)
    ]]
end)

test("{[number]: any}", function()
    check(run[[local a: {[number] = any} = {[1] = 1}]], "{ number ⊃ number(1) = any ⊃ number(1) }")
    run([[local a: {[number] = any} = {foo = 1}]], [[has no field "foo"]])
end)


test("{[1 .. inf]: any}", function()
    check(run[[local a: {[1 .. inf] = any} = {[1234] = 1}]], "{ 1..inf ⊃ 1234 = any ⊃ number(1) }")

    run([[local a: {[1 .. inf] = any} = {[-1234] = 1}]], [[has no field %-1234]])
end)

test("traditional array", function()
    run[[
        local function Array<|T: any, L: number|>
            return {[1 .. L] = T}
        end

        local list: Array<|number, 3|> = {1, 2, 3}
    ]]

    run([[
        local function Array<|T: any, L: number|>
            return {[1 .. L] = T}
        end

        local list: Array<|number, 3|> = {1, 2, 3, 4}
    ]], "has no field 4")
end)

run[[
    local a: [1,2,3] = {1,2,3}
    type_assert(a[1], 1)
]]

run[[
    local a: string[]
    type_assert(a[1], _ as string)
]]