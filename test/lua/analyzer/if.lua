local T = require("test.helpers")
local run = T.RunCode

test("if statement within a function", function()
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

test("assigning a value inside an uncertain branch", function()
    run([[
        local a = false

        if _ as any then
            type_assert(a, false)
            a = true
            type_assert(a, true)
        end
        type_assert(a, _ as false | true)
    ]])
end)

test("assigning in uncertain branch and else part", function()
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
end)

test("nil | 1 should be 1 inside branch when tested for", function()
    run([[
        local a: nil | 1

        if a then
            type_assert(a, _ as 1 | 1)
        end

        type_assert(a, _ as 1 | nil)
    ]])

    run([[
        local a: nil | 1

        if a then
            type_assert(a, _ as 1 | 1)
        else
            type_assert(a, _ as nil | nil)
        end

        type_assert(a, _ as 1 | nil)
    ]])
end)


test("uncertain branches should add nil to assignment", function()
    run([[
        local _: boolean
        local a = 0
    
        if _ then
            a = 1
        end
        type_assert(a, _ as 0 | 1)
    ]])
end)

test("nested assignment", function()
    run[[
        local a: nil | 1
    
        if a then
            type_assert(a, _ as 1 | 1)
            if a then
                if a then
                    type_assert(a, _ as 1 | 1)
                end
                type_assert(a, _ as 1 | 1)
            end
        end
    
        type_assert(a, _ as 1 | nil)
    ]]
end)

test("inverted", function()
    run([[
        local a: nil | 1
    
        if not a then
            type_assert(a, _ as nil | nil)
        end
    
        type_assert(a, _ as 1 | nil)
    ]])
end)

test("inverted else", function()
    run[[
        local a: true | false

        if not a then
            type_assert(a, false)
        else
            type_assert(a, true)
        end
    ]]
end)

test("type function", function()
    run([[
        local a: number | string

        if type(a) == "number" then
            type_assert(a, _ as number)
        end

        type_assert(a, _ as number | string)
    ]])
    run[[
        local a: 1 | false | true

        if type(a) == "boolean" then
            type_assert(a, _ as boolean)
        end

        if type(a) ~= "boolean" then
            type_assert(a, 1)
        else
            type_assert(a, _ as boolean)
        end
    ]]
end)

pending("inverted", function()
    run([[
        local a: nil | 1
    
        if not not a then
            type_assert(a, _ as nil | nil)
        end
    
        type_assert(a, _ as 1 | nil)
    ]])
end)

pending("inverted2", function()
    run([[
        local a: nil | 1
    
        if not not a then
            type_assert(a, _ as 1 | 1)
        end
    
        type_assert(a, _ as 1 | nil)
    ]])
end)

pending("inverted", function()
    run([[
        local a: nil | 1

        if a or true and a or false then
            type_assert(a, _ as 1 | 1)
        end

        type_assert(a, _ as 1 | nil)
    ]])
end)

pending([[
    local a: nil | 1

    if not a or true and a or false then
        type_assert(a, _ as 1 | nil)
    end

    type_assert(a, _ as 1 | nil)
]])

do
    _G.lol = nil

    run([[
        local type hit = function()
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


run[[
local a = false

type_assert(a, false)

if maybe then
    a = true
    type_assert(a, true)
end

type_assert(a, _ as true | false)
]]

run[[
local a: true | false

if a then
    type_assert(a, true)
else
    type_assert(a, false)
end

if not a then
    type_assert(a, false)
else
    type_assert(a, true)
end

if not a then
    if a then
        type_assert("this should never be reached")
    end
else
    if a then
        type_assert(a, true)
    else
        type_assert("unreachable code!!")
    end
end
]]


run[[
local a: nil | 1
    
if a then
    type_assert(a, _ as 1 | 1)
    if a then
        if a then
            type_assert(a, _ as 1 | 1)
        end
        type_assert(a, _ as 1 | 1)
    end
end

type_assert(a, _ as 1 | nil)
]]

run[[
    local x: true | false
    
    if x then return end
    
    type_assert(x, false)
]]

run[[
    local x: true | false
    
    if not x then return end
    
    type_assert(x, true)
]]

run[[
    local c = 0

    if maybe then
        c = c + 1
    else
        c = c - 1
    end

    type_assert(c, _ as -1 | 1)
]]

pending("never", function()
    run[[
        local a: true

        if a then
            return
        end

        type_assert(a, _ as never)
    ]]


    run[[
        local a = true

        if a then
            error("!")
        end

        type_assert(a, _ as never)
    ]]
end)
pending([[
    local a: nil | 1
    if not a then return end
    type_assert(a, 1)
]])

pending([[
    local a: nil | 1
    if a then return end
    type_assert(a, nil)
]])



run[[
    local a = true

    if maybe then
        error("!")
    end

    type_assert(a, true)
]]

run[[
    local a = true

    while maybe do
        a = false
    end

    type_assert(a, _ as true | false)
]]

run[[
    local a = true

    for i = 1, 10 do
        a = false
    end

    type_assert(a, _ as false)
]]

run[[
    local a = true

    for i = 1, _ as number do
        a = false
    end

    type_assert(a, _ as true | false)
]]

run[[
    local a: {[string] = number}
    local b = true

    for k,v in pairs(a) do
        b = false
    end

    type_assert(b, _ as true | false)
]]

run[[
    local a: {foo = number}
    local b = true

    for k,v in pairs(a) do
        b = false
    end

    type_assert(b, _ as false)
]]


test("branching", function()
    run([[
        local type a = {}

        if not a then
            -- shouldn't reach
            type_assert(1, 2)
        else
            type_assert(1, 1)
        end
    ]])

    run([[
        local type a = {}
        if not a then
            -- shouldn't reach
            type_assert(1, 2)
        end
    ]])
end)

run[[
    local a: true | false | number | "foo" | "bar" | nil | 1

    if a then
        type_assert(a, _ as true | number | "foo" | "bar" | 1)
    else
        type_assert(a, _ as false | nil)
    end

    if not a then
        type_assert(a, _ as false | nil)
    end

    if a == "foo" then
        type_assert(a, "foo")
    end
]]