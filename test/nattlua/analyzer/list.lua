local T = require("test.helpers")
local run = T.RunCode

local check = function(analyzer, to)
    equal(to:gsub("%s+", " "), tostring(analyzer:GetLocalOrGlobalValue(T.String("a"))):gsub("%s+", " "), 2)
end


test("can be simple", function()
    run[[
        local x = {1, 2, 3}
        x[2] = 10

        types.assert(x[2], 10)
    ]]
end)

test("can be sparse", function()
    run[[
        local x = {
            [2] = 2,
            [10] = 3,
        }

        types.assert(x[10], 3)
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
        types.assert(x[RED], 2)
    ]]
end)


test("{[number]: any}", function()
    check(run[[local a: {[number] = any} = {[1] = 1}]], "{ [number(1) as number] = number(1) as any }")
    run([[local a: {[number] = any} = {foo = 1}]], [[has no field "foo"]])
end)


test("{[1 .. inf]: any}", function()
    check(run[[local a: {[1 .. inf] = any} = {[1234] = 1}]], "{ [1234 as 1..inf] = number(1) as any }")

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
    local a: {1,2,3} = {1,2,3}
    types.assert(a[1], 1)
]]

run[[
    local a: {[number]=string}
    types.assert(a[1], _ as string)
]]