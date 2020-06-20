local T = require("spec.lua.helpers")
local run = T.RunCode

local check = function(analyzer, to)
    assert.equal(to:gsub("%s+", " "), tostring(analyzer:GetValue("a", "runtime")):gsub("%s+", " "))
end

describe("lists", function()

    it("can be simple", function()
        run[[
            local x = {1, 2, 3}
            x[2] = 10

            type_assert(x[2], 10)
        ]]
    end)

    it("can be sparse", function()
        run[[
            local x = {
                [2] = 2,
                [10] = 3,
            }

            type_assert(x[10], 3)
        ]]
    end)

    it("can be indirect", function()
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

    it("indirect only works for numeric keys", function()
        run[[
            local RED = 1
            local BLUE = 2
            local GREEN: string = (function():string return "hello" end)()
            local x = {
                [RED] = 2,
                [BLUE] = 3,
                [GREEN] = 4,
            }
            type_assert(x[GREEN], 4)
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

    it("indirect works array-records", function()
        run[[
            local tbl = {}
            for i = 1, 100 do
                tbl[i] = i*100
            end
            tbl[50] = true
            type_assert(tbl[20], _ as 100 .. 10000 | true)
        ]]
    end)

    it("{[number]: any}", function()
        check(run[[local a: {[number] = any} = {[1] = 1}]], "{ number ⊃ number(1) = any ⊃ number(1) }")
        run([[local a: {[number] = any} = {foo = 1}]], [[is not the same type as number]])
    end)


    it("{[1 .. inf]: any}", function()
        check(run[[local a: {[1 .. inf] = any} = {[1234] = 1}]], "{ 1..inf ⊃ 1234 = any ⊃ number(1) }")

        run([[local a: {[1 .. inf] = any} = {[-1234] = 1}]], [[number%(%-1234%) is not a subset of 1%.%.inf]])
    end)

    it("traditional array", function()
        run[[
            local function Array<T: any, L: number>
                return {[1 .. L] = T}
            end

            local list: Array<number, 3> = {1, 2, 3}
        ]]

        run([[
            local function Array<T: any, L: number>
                return {[1 .. L] = T}
            end

            local list: Array<number, 3> = {1, 2, 3, 4}
        ]], "because 4 is not a subset of 1%.%.3")
    end)
end)