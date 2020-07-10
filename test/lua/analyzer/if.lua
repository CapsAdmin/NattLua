local T = require("test.helpers")
local run = T.RunCode

it("if statement within a function should work", function()
    run([[
        local a = 1
        function b(lol)
            if lol == 1 then return "foo" end
            return lol + 4, true
        end
        local d = b(2)
        type_assert(d, 6)
        local d = b(a)
        type_assert(d, "foo")
    ]])


    run[[
        local function test(i)
            if i == 20 then
                return false
            end

            if i == 5 then
                return true
            end

            return "lol"
        end

        local a = test(20) -- false
        local b = test(5) -- true
        local c = test(1) -- "lol"

        type_assert(a, false)
        type_assert(b, true)
        type_assert(c, "lol")
    ]]

    run[[
        local function test(max)
            for i = 1, max do
                if i == 20 then
                    return false
                end

                if i == 5 then
                    return true
                end
            end
        end

        local a = test(20)
        type_assert(a, _ as true | false)
    ]]
end)

run([[
    local a = false

    if _ as any then
        type_assert(a, false)
        a = true
        type_assert(a, true)
    end
    type_assert(a, _ as false | true)
]])

run([[
    local a = false

    if _ as any then
        a = true
    else
        a = 1
    end

    type_assert(a, _ as true | 1)
]])

run([[
    local a = false

    if _ as any then
        type_assert(a, false)
        a = true
        type_assert(a, true)
    else
        type_assert(a, false)
        a = 1
        type_assert(a, 1)
    end

    type_assert(a, _ as true | 1)
]])

run([[
    local a = nil

    if _ as any then
        a = true
    end

    type_assert(a, _ as true | nil)
]])

do
    _G.lol = nil

    run([[
        type hit = function()
            lol = (lol or 0) + 1
        end

        local a: number
        local b: number

        if a == b then
            hit()
        else
            hit()
        end
    ]])

    equal(2, _G.lol)
    _G.lol = nil
end

run([[
    local a: 1
    local b: 1

    local c = 0

    if a == b then
        c = c + 1
    else
        c = c - 1
    end

    type_assert(c, 1)
]])


run([[
    local a: number
    local b: number

    local c = 0

    if a == b then
        c = c + 1
    else
        c = c - 1
    end

    type_assert(c, _ as -1 | 1)
]])
