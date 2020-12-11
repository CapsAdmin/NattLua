local T = require("test.helpers")
local run = T.RunCode

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

run[[
    local x = 0
    local MAYBE: true | false

    if MAYBE then
        x = 1
    end

    if MAYBE2 then
        type_assert<|x, 0 | 1|>
        x = 2
    end

    if MAYBE then
        type_assert<|x, 1 | 2|>
    end

]]

run([[
    -- assigning a value inside an uncertain branch
    local a = false

    if _ as any then
        type_assert(a, false)
        a = true
        type_assert(a, true)
    end
    type_assert(a, _ as false | true)
]])

run([[
    -- assigning in uncertain branch and else part
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
    local a: nil | 1

    if a then
        type_assert(a, _ as 1)
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

run([[
    local a = 0

    if MAYBE then
        a = 1
    end
    type_assert(a, _ as 0 | 1)
]])

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

run([[
    local a: nil | 1

    if not a then
        type_assert(a, _ as nil | nil)
    end

    type_assert(a, _ as 1 | nil)
]])

run[[
    local a: true | false

    if not a then
        type_assert(a, false)
    else
        type_assert(a, true)
    end
]]

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

do
    _G.lol = nil

    run([[
        local type hit = function()
            _G.lol = (_G.lol or 0) + 1
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
    local x: false | 1
    assert(not x)
    type_assert(x, false)
]]

run[[
    local x: false | 1
    assert(x)
    type_assert(x, 1)
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

run([[
    local a: nil | 1
    if not a then return end
    type_assert(a, 1)
]])

run([[
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
        type_assert(k, _ as string)
        type_assert(v, _ as number)
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

run[[
    local x: nil | true

    if not x then
        return
    end

    do
        do
            type_assert(x, true)
        end
    end
]]

run[[
    local function parse_unicode_escape(s: string)
        local n = tonumber(s:sub(1, 1))
        
        if not n then
            return
        end
        
        if true then
            return n + 1
        end
    end
]]

run[[
    local function parse_unicode_escape(s: string)
        local n = tonumber(s:sub(1, 1))
        
        if not n then
            return
        end
        
        if true then
            local a = n
            return a + 1
        end
    end
]]

run[[
    do
        local s: string
        local _1337_false: false | 1337
        local _7777_false: false | 7777
    
        if not _1337_false then
            return
        end
    
        if not _7777_false then
            return
        end
    
        if _7777_false then
            return _1337_false - 1
        end
    end
]]

run[[
    local a: 1 | nil

    if not a then
        error("!")
    end

    type_assert(a, 1)
]]

run[[
    local a: 1 | nil

    if not a then
        assert(false)
    end

    type_assert(a, 1)
]]

run[[
    local a = assert(_ as 1 | nil)
    --type_assert(a, 1)
]]


run[[
    local MAYBE: function(): boolean
    local x = 0
    if MAYBE() then x = x + 1 end -- 1
    if MAYBE() then x = x - 1 end -- -1 | 0
    type_assert(x, _ as -1 | 0 | 1)
]]

run[[
    local x = 0
    if MAYBE then
        x = 1
    else
        x = -1
    end
    type_assert(x, _ as -1 | 1)
]]

run[[
    local x = 0
    if MAYBE then
        x = 1
    end
    type_assert(x, _ as 0 | 1)
]]

run[[
    x = 1

    if MAYBE then
        x = 2
    end

    if MAYBE then
        x = 3
    end

    type_assert(x, _ as 1|2|3)

    x = nil
]]

run[[
    local foo = false

    if MAYBE then
        foo = true
    end

    if true then
        foo = true
    end

    type_assert(foo, true)
]]


run[[
    local x: true | false | 2

    if x then    
        type_assert(x, _ as true | 2)
        x = 1
    end

    type_assert<|x, true | false | 2 | 1|>
]]

run[[
    local x = 1

    if MAYBE then
        if true then
            x = 2
        end
    end

    type_assert(x, _ as 1 | 2)
]]

run[[
    local x = 1

    if false then
        
    else
        x = 2
    end

    type_assert(x, _ as 2)
]]

run[[
    local x = 1

    if MAYBE then
        x = 2
    end

    if MAYBE then
        x = 3
    end

    type_assert(x, _ as 1 | 2 | 3)
]]


run[[
    --DISABLE_CODE_RESULT

    local x = 1

    if MAYBE then
        type_assert<|x, 1|>
        x = 2
        type_assert<|x, 2|>
    elseif MAYBE then
        type_assert<|x, 1|>
        x = 3
        type_assert<|x, 3|>
    elseif MAYBE then
        type_assert<|x, 1|>
        x = 4
        type_assert<|x, 4|>
    end

    type_assert<|x, 1 | 2 | 3 | 4|>
]]

run[[
    local foo = false

    if MAYBE then
        foo = true
    end
    if not foo then
        return
    end

    type_assert(foo, true)
]]

run[[
    local x: 1 | "1"
    local y = type(x) == "number"
    if y then
        type_assert(y, 1)
    else
        type_assert(y, "1")
    end
]]

run[[
    local x: 1 | "1"
    local y = type(x) ~= "number"
    if y then
        type_assert(y, "1")
    else
        type_assert(y, 1)
    end
]]

run[[
    local x: 1 | "1"
    local t = "number"
    local y = type(x) ~= t
    if y then
        type_assert(y, "1")
    else
        type_assert(y, 1)
    end
]]

run[=[
    
    do
        local x = 1
        type_assert<|x, 1|>
    end
    
    do
        local x = 1
        do
            type_assert<|x, 1|>
        end
    end
    
    do
        local x = 1
        x = 2
        type_assert<|x, 2|>
    end
    
    do
        local x = 1
        if true then
            x = 2
        end
        type_assert<|x, 2|>
    end
    
    do
        local x = 1
        if MAYBE then
            x = 2
        end
        type_assert<|x, 1 | 2|>
    end
    
    do
        local x = 1
        if MAYBE then
            type_assert<|x, 1|>
            x = 2
            type_assert<|x, 2|>
        end
        type_assert<|x, 1|2|>
    end
    
    do
        local x = 1
    
        if MAYBE then
            type_assert<|x, 1|>
            x = 1.5
            type_assert<|x, 1.5|>
            x = 1.75
            type_assert<|x, 1.75|>
            if MAYBE then
                x = 2
                if MAYBE then
                    x = 2.5
                end
                type_assert<|x, 2 | 2.5|>
            end
            x = 3
            type_assert<|x, 3|>
        end
        
        type_assert<|x, 1 | 3|>
    end
    
    do return end
    do
        local x = 1
    
        if MAYBE then
            if true then
                do
                    x = 1337
                end
            end
            type_assert<|x, 1337|>
            x = 2
            type_assert<|x, 2|>
        else
            type_assert<|x, 1|>
            x = 66
        end
        
        type_assert<|x, 1 | 2|>
    end 
    
    do
        local x = 1
    
        if MAYBE then
            x = 2
            type_assert<|x, 2|>
        else
            type_assert<|x, 1|>
            x = 3
        end
        type_assert<|x, 2 | 3|>
    end

    do
        local x = 1
    
        if MAYBE then
            x = 2
        elseif MAYBE then
            x = 3
        elseif MAYBE then
            x = 4
        end
    
        type_assert<|x, 1|2|3|4|>
    end

    do
        local x = 1
    
        if MAYBE then
            x = 2
        elseif MAYBE then
            x = 3
        elseif MAYBE then
            x = 4
        else
            x = 5
        end
    
        type_assert<|x, 5|2|3|4|>
    end

    do
        local x = 1
    
        
        if MAYBE then
            x = 2
    
            if MAYBE then
                x = 1337
            end
    
            x = 0 -- the last one counts
    
        elseif MAYBE then
            x = 3
        elseif MAYBE then
            x = 4
        end
    
        type_assert<|x, 0 | 1 | 3 | 4|>
    end
    
    do return end
    --[[
    elseif MAYBE then
        type_assert<|x, 1|>
        x = 3
        type_assert<|x, 3|>
    elseif MAYBE then
        type_assert<|x, 1|>
        x = 4
        type_assert<|x, 4|>
    else
        type_assert<|x, 1|>
        x = 5
        type_assert<|x, 5|>
    end
    
    print(x)
    
    --type_assert<|x, 1 | 2 | 3 | 4|>
    ]]
]=]

run([[
    local x = 1

    if x == 1 then
        x = 2
    end

    if x == 2 then
        x = 3
    end

    type_assert<|x, 3|>
]])


run[[
    local x: -1 | 0 | 1 | 2 | 3

    if x >= 0 then
        if x >= 1 then
            type_assert<|x, 1|2|3|>
        end
    end
]]

run[[
    local x: -1 | 0 | 1 | 2 | 3
    local y = x >= 0 and x or nil
    type_assert<|y, 0 | 1 | 2 | 3 | nil|>

    local y = x >= 0 and x >= 1 and x or nil
    type_assert<|y, 1 | 2 | 3 | nil|>
]]

run[[
    local function test(LOL)
        type_assert(LOL, 1)
    end
    
    local x: 1 | "str"
    if x == 1 or test(x) then
    
    end
]]

run[[
    local function test(LOL)
        type_assert(LOL, 1)
    end
    
    local x: 1 | "str"
    if x ~= 1 or test(x) then
    
    end
]]

run[[
    local function test(LOL)
        return LOL
    end
    
    local x: 1 | "str"
    local y = x ~= 1 or test(x)
    
    type_assert<|y, 1 | true|>
]]

run[[
    local function foo(input)
        local x = tonumber(input)
        if not x then
            error("!")
        end
        return x
    end
    
    local y = foo(_ as string)
    type_assert<|y, number|>
]]

pending([[
    local a: nil | 1

    if not a or true and a or false then
        type_assert(a, _ as 1 | nil)
    end

    type_assert(a, _ as 1 | nil)
]])

pending[[
    local MAYBE: boolean
    local x = 0
    if MAYBE then x = x + 1 end -- 1
    if MAYBE then x = x - 1 end -- 0
    type_assert(x, 0)
]]

pending[[
    local MAYBE: boolean

    x = 1

    if MAYBE then
        x = 2
    end

    if MAYBE then
        x = 3
    end

    type_assert(x, _ as 2|3)

    x = nil
]]


pending[[
    local a: nil | 1

    if not not a then
        type_assert(a, _ as nil | nil)
    end

    type_assert(a, _ as 1 | nil)
]]

pending[[
    local a: nil | 1

    if not not a then
        type_assert(a, _ as 1 | 1)
    end

    type_assert(a, _ as 1 | nil)
]]

pending[[
    local a: nil | 1

    if a or true and a or false then
        type_assert(a, _ as 1 | 1)
    end

    type_assert(a, _ as 1 | nil)
]]
