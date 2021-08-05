local T = require("test.helpers")
local run = T.RunCode

run([[
    local a = 1
    function b(lol)
        if lol == 1 then return "foo" end
        return lol + 4, true
    end
    local d = b(2)
    types.assert(d, 6)
    local d = b(a)
    types.assert(d, "foo")
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

    types.assert(a, false)
    types.assert(b, true)
    types.assert(c, "lol")
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
    types.assert(a, _ as true | false)
]]

run[[
    local x = 0
    local MAYBE: true | false

    if MAYBE then
        x = 1
    end

    if MAYBE2 then
        types.assert<|x, 0 | 1|>
        x = 2
    end

    if MAYBE then
        types.assert<|x, 1 | 2|>
    end

]]

run([[
    -- assigning a value inside an uncertain branch
    local a = false

    if _ as any then
        types.assert(a, false)
        a = true
        types.assert(a, true)
    end
    types.assert(a, _ as false | true)
]])

run([[
    -- assigning in uncertain branch and else part
    local a = false

    if _ as any then
        types.assert(a, false)
        a = true
        types.assert(a, true)
    else
        types.assert(a, false)
        a = 1
        types.assert(a, 1)
    end

    types.assert(a, _ as true | 1)
]])

run([[
    local a: nil | 1

    if a then
        types.assert(a, _ as 1)
    end

    types.assert(a, _ as 1 | nil)
]])

run([[
    local a: nil | 1

    if a then
        types.assert(a, _ as 1 | 1)
    else
        types.assert(a, _ as nil | nil)
    end

    types.assert(a, _ as 1 | nil)
]])

run([[
    local a = 0

    if MAYBE then
        a = 1
    end
    types.assert(a, _ as 0 | 1)
]])

run[[
    local a: nil | 1

    if a then
        types.assert(a, _ as 1 | 1)
        if a then
            if a then
                types.assert(a, _ as 1 | 1)
            end
            types.assert(a, _ as 1 | 1)
        end
    end

    types.assert(a, _ as 1 | nil)
]]

run([[
    local a: nil | 1

    if not a then
        types.assert(a, _ as nil | nil)
    end

    types.assert(a, _ as 1 | nil)
]])

run[[
    local a: true | false

    if not a then
        types.assert(a, false)
    else
        types.assert(a, true)
    end
]]

run([[
    local a: number | string

    if type(a) == "number" then
        types.assert(a, _ as number)
    end

    types.assert(a, _ as number | string)
]])

run[[
    local a: 1 | false | true

    if type(a) == "boolean" then
        types.assert(a, _ as boolean)
    end

    if type(a) ~= "boolean" then
        types.assert(a, 1)
    else
        types.assert(a, _ as boolean)
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

    types.assert(c, 1)
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

    types.assert(c, _ as -1 | 1)
]])


run[[
    local a = false

    types.assert(a, false)

    if maybe then
        a = true
        types.assert(a, true)
    end

    types.assert(a, _ as true | false)
]]

run[[
    local a: true | false

    if a then
        types.assert(a, true)
    else
        types.assert(a, false)
    end

    if not a then
        types.assert(a, false)
    else
        types.assert(a, true)
    end

    if not a then
        if a then
            types.assert("this should never be reached")
        end
    else
        if a then
            types.assert(a, true)
        else
            types.assert("unreachable code!!")
        end
    end
]]


run[[
    local a: nil | 1
        
    if a then
        types.assert(a, _ as 1 | 1)
        if a then
            if a then
                types.assert(a, _ as 1 | 1)
            end
            types.assert(a, _ as 1 | 1)
        end
    end

    types.assert(a, _ as 1 | nil)
]]

run[[
    local x: false | 1
    assert(not x)
    types.assert(x, false)
]]

run[[
    local x: false | 1
    assert(x)
    types.assert(x, 1)
]]

run[[
    local x: true | false
    
    if x then return end
    
    types.assert(x, false)
]]

run[[
    local x: true | false
    
    if not x then return end
    
    types.assert(x, true)
]]

run[[
    local c = 0

    if maybe then
        c = c + 1
    else
        c = c - 1
    end

    types.assert(c, _ as -1 | 1)
]]

run([[
    local a: nil | 1
    if not a then return end
    types.assert(a, 1)
]])

run([[
    local a: nil | 1
    if a then return end
    types.assert(a, nil)
]])


do
    _G.TEST_DISABLE_ERROR_PRINT = true
    run[[
        local a = true

        if maybe then
            error("!")
        end

        types.assert(a, true)
    ]]
    _G.TEST_DISABLE_ERROR_PRINT = false
end

run[[
    local a = true

    while maybe do
        a = false
    end

    types.assert(a, _ as true | false)
]]

run[[
    local a = true

    for i = 1, 10 do
        a = false
    end

    types.assert(a, _ as false)
]]

run[[
    local a = true

    for i = 1, _ as number do
        a = false
    end

    types.assert(a, _ as true | false)
]]

run[[
    local a: {[string] = number}
    local b = true

    for k,v in pairs(a) do
        types.assert(k, _ as string)
        types.assert(v, _ as number)
        b = false
    end

    types.assert(b, _ as true | false)
]]

run[[
    local a: {foo = number}
    local b = true

    for k,v in pairs(a) do
        b = false
    end

    types.assert(b, _ as false)
]]

run([[
    local type a = {}

    if not a then
        -- shouldn't reach
        types.assert(1, 2)
    else
        types.assert(1, 1)
    end
]])

run([[
    local type a = {}
    if not a then
        -- shouldn't reach
        types.assert(1, 2)
    end
]])

run[[
    local a: true | false | number | "foo" | "bar" | nil | 1

    if a then
        types.assert(a, _ as true | number | "foo" | "bar" | 1)
    else
        types.assert(a, _ as false | nil)
    end

    if not a then
        types.assert(a, _ as false | nil)
    end

    if a == "foo" then
        types.assert(a, "foo")
    end
]]

run[[
    local x: nil | true

    if not x then
        return
    end

    do
        do
            types.assert(x, true)
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

do
    _G.TEST_DISABLE_ERROR_PRINT = true
    run[[
        local a: 1 | nil

        if not a then
            error("!")
        end

        types.assert(a, 1)
    ]]
end

run[[
    local a: 1 | nil

    if not a then
        assert(false)
    end

    types.assert(a, 1)
]]

run[[
    local a = assert(_ as 1 | nil)
    --types.assert(a, 1)
]]


run[[
    local MAYBE: function(): boolean
    local x = 0
    if MAYBE() then x = x + 1 end -- 1
    if MAYBE() then x = x - 1 end -- -1 | 0
    types.assert(x, _ as -1 | 0 | 1)
]]

run[[
    local x = 0
    if MAYBE then
        x = 1
    else
        x = -1
    end
    types.assert(x, _ as -1 | 1)
]]

run[[
    local x = 0
    if MAYBE then
        x = 1
    end
    types.assert(x, _ as 0 | 1)
]]

run[[
    x = 1

    if MAYBE then
        x = 2
    end

    if MAYBE then
        x = 3
    end

    types.assert(x, _ as 1|2|3)

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

    types.assert(foo, true)
]]


run[[
    local x: true | false | 2

    if x then    
        types.assert(x, _ as true | 2)
        x = 1
    end

    types.assert<|x, true | false | 2 | 1|>
]]

run[[
    local x = 1

    if MAYBE then
        if true then
            x = 2
        end
    end

    types.assert(x, _ as 1 | 2)
]]

run[[
    local x = 1

    if false then
        
    else
        x = 2
    end

    types.assert(x, _ as 2)
]]

run[[
    local x = 1

    if MAYBE then
        x = 2
    end

    if MAYBE then
        x = 3
    end

    types.assert(x, _ as 1 | 2 | 3)
]]


run[[
    --DISABLE_CODE_RESULT

    local x = 1

    if MAYBE then
        types.assert<|x, 1|>
        x = 2
        types.assert<|x, 2|>
    elseif MAYBE then
        types.assert<|x, 1|>
        x = 3
        types.assert<|x, 3|>
    elseif MAYBE then
        types.assert<|x, 1|>
        x = 4
        types.assert<|x, 4|>
    end

    types.assert<|x, 1 | 2 | 3 | 4|>
]]

run[[
    local foo = false

    if MAYBE then
        foo = true
    end
    if not foo then
        return
    end

    types.assert(foo, true)
]]

run[=[
    
    do
        local x = 1
        types.assert<|x, 1|>
    end
    
    do
        local x = 1
        do
            types.assert<|x, 1|>
        end
    end
    
    do
        local x = 1
        x = 2
        types.assert<|x, 2|>
    end
    
    do
        local x = 1
        if true then
            x = 2
        end
        types.assert<|x, 2|>
    end
    
    do
        local x = 1
        if MAYBE then
            x = 2
        end
        types.assert<|x, 1 | 2|>
    end
    
    do
        local x = 1
        if MAYBE then
            types.assert<|x, 1|>
            x = 2
            types.assert<|x, 2|>
        end
        types.assert<|x, 1|2|>
    end
    
    do
        local x = 1
    
        if MAYBE then
            types.assert<|x, 1|>
            x = 1.5
            types.assert<|x, 1.5|>
            x = 1.75
            types.assert<|x, 1.75|>
            if MAYBE then
                x = 2
                if MAYBE then
                    x = 2.5
                end
                types.assert<|x, 2 | 2.5|>
            end
            x = 3
            types.assert<|x, 3|>
        end
        
        types.assert<|x, 1 | 3|>
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
            types.assert<|x, 1337|>
            x = 2
            types.assert<|x, 2|>
        else
            types.assert<|x, 1|>
            x = 66
        end
        
        types.assert<|x, 1 | 2|>
    end 
    
    do
        local x = 1
    
        if MAYBE then
            x = 2
            types.assert<|x, 2|>
        else
            types.assert<|x, 1|>
            x = 3
        end
        types.assert<|x, 2 | 3|>
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
    
        types.assert<|x, 1|2|3|4|>
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
    
        types.assert<|x, 5|2|3|4|>
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
    
        types.assert<|x, 0 | 1 | 3 | 4|>
    end
    
    do return end
    --[[
    elseif MAYBE then
        types.assert<|x, 1|>
        x = 3
        types.assert<|x, 3|>
    elseif MAYBE then
        types.assert<|x, 1|>
        x = 4
        types.assert<|x, 4|>
    else
        types.assert<|x, 1|>
        x = 5
        types.assert<|x, 5|>
    end
    
    print(x)
    
    --types.assert<|x, 1 | 2 | 3 | 4|>
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

    types.assert<|x, 3|>
]])


run[[
    local x: -1 | 0 | 1 | 2 | 3
    local y = x >= 0 and x or nil
    types.assert<|y, 0 | 1 | 2 | 3 | nil|>

    local y = x >= 0 and x >= 1 and x or nil
    types.assert<|y, 1 | 2 | 3 | nil|>
]]

run[[
    local function test(LOL)
        types.assert(LOL, 1)
    end
    
    local x: 1 | "str"
    if x == 1 or test(x) then
    
    end
]]

run[[
    local function test(LOL)
        types.assert(LOL, 1)
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
    
    types.assert<|y, 1 | true|>
]]

do
    _G.TEST_DISABLE_ERROR_PRINT = true
    run[[
        local function foo(input)
            local x = tonumber(input)
            if not x then
                error("!")
            end
            return x
        end
        
        local y = foo(_ as string)
        types.assert<|y, number|>
    ]]
    _G.TEST_DISABLE_ERROR_PRINT = false
end

run[[
    local a = {}
    if MAYBE then
        a.lol = true
        types.assert(a.lol, true)
    end
    types.assert(a.lol, _ as nil | true)
]]

run[[
    if _ as boolean then
        local function foo() 
            local c = {}
            c.foo = true
            
            if _ as boolean then
                local function test()
                    local x = c.foo
                    types.assert(x, true)
                end
                test()
            end
        end
        foo()
    end
]]

run[[
    local tbl = {foo = 1}

    if MAYBE then
        tbl.foo = 2
        types.assert(tbl.foo, 2)
    end
    
    types.assert(tbl.foo, _ as 1 | 2)
]]

run[[
    local tbl = {foo = {bar = 1}}

    if MAYBE then
        tbl.foo.bar = 2
        types.assert(tbl.foo.bar, 2)
    end

    types.assert(tbl.foo.bar, _ as 1 | 2)
]]

run[[
    local x: {
        field = number | nil,
    } = {}
    
    if MAYBE then
        x.field = nil
        types.assert(x.field, nil)
    end
    types.assert(x.field, _ as number | nil)
]]


run[[
    local x = { lol = _ as false | 1 }
    if not x.lol then
        x.lol = 1 
    end
    types.assert<|x.lol, 1|>
]]

run[[
    local x = { lol = _ as false | 1 }
    if not x.lol then
        if MAYBE then
            x.lol = 1 
        end
    end
    types.assert(x.lol, _ as false | 1)
]]

run[[
    assert(maybe)

    local y = 1

    local function foo()
        local x = 1
        return 1
    end    

    types.assert(foo(), 1)
]]

run[[
    local function lol()
        if MAYBE then
            return 1
        end
    end
    
    local x = lol()
    
    types.assert<|x, 1 | nil|>
]]

run[[
    --DISABLE_CODE_RESULT

    local type HeadPos = {
        findheadpos_head_bone = number | false,
        findheadpos_head_attachment = number | nil,
        findheadpos_last_mdl = string | nil,
        @Name = "BlackBox",
    }

    local function FindHeadPosition(ent: HeadPos)
        
        if MAYBE then
            ent.findheadpos_head_bone = false
        end
        
        if ent.findheadpos_head_bone then

        else
            if not ent.findheadpos_head_attachment then
                ent.findheadpos_head_attachment = _ as nil | number 
            end

            types.assert<|ent.findheadpos_head_attachment, nil | number|>
        end
    end
]]

run[[
    local function test()
        if MAYBE then
            return "test"
        else
            return "foo"
        end
    end
    
    local x = test()
    
    types.assert(x, _ as "test" | "foo")
]]

run[[
    local x: {foo = nil | 1}

    if x.foo then
        types.assert(x.foo, 1)
    end
]]

run[[
    local MAYBE1: boolean
    local MAYBE2: boolean

    local x =  1

    if MAYBE1 then
        x = 2
    else
        if MAYBE2 then
            x = 3
        else
            x = 4
        end
    end

    types.assert(x, _ as 2 | 3 | 4)
]]

run[[
    local MAYBE1: boolean
    local MAYBE2: boolean

    local x

    if MAYBE1 then
        x = function() return 1 end
    else
        if MAYBE2 then
            x = function() return 2 end
        else
            x = function() return 3 end
        end
    end
    
    -- none of the functions are called anywhere when looking x up, so x becomes just "function()" from the union's point of view
    -- this ensures that they are inferred before being added
    types.assert(x(), _ as 1 | 2 | 3)
]]

run[[
    local x

    if _ as boolean then
        x = 1
    else
        x = 2
    end

    types.assert(x, _ as 1 | 2)

    local function lol()
        types.assert(x, _ as 1 | 2)
    end

    lol()
]]

run[[
    if math.random() > 0.5 then
        FOO = 1
    
        types.assert(FOO, 1)
        
        do
            types.assert(FOO, 1)
        end
    end
]]

run[[
    assert(math.random() > 0.5)

    LOL = true

    if math.random() > 0.5 then end

    types.assert(LOL, true)
]]

run[[
    local foo = {}
    assert(math.random() > 0.5)

    foo.bar = 1

    if math.random() > 0.5 then end

    types.assert<|typeof foo.bar, 1|>
]]

run[[
    local foo = 1

    assert(_ as boolean)

    if _ as boolean then
        foo = 2

        if _ as boolean then
            local a = 1
        end

        types.assert(foo, 2)
    end
]]

run[[
    local foo = 1

    assert(_ as boolean)

    if _ as boolean then
        foo = 2

        if _ as boolean then
            local a = 1
        else

        end

        types.assert(foo, 2)
    end
]]

run[[
    local function test(x: literal any)
        types.assert(x, true)
        return true
    end
    
    local function foo(x: {foo = boolean | nil}) 
        if x.foo and test(x.foo) then
            types.assert(x.foo, true)
        end
    end
]]

pending([[
    local a: nil | 1

    if not a or true and a or false then
        types.assert(a, _ as 1 | nil)
    end

    types.assert(a, _ as 1 | nil)
]])

pending[[
    local MAYBE: boolean
    local x = 0
    if MAYBE then x = x + 1 end -- 1
    if MAYBE then x = x - 1 end -- 0
    types.assert(x, 0)
]]

run[[
    local MAYBE: boolean

    x = 1

    if MAYBE then
        x = 2
    end

    if MAYBE then
        x = 3
    end

    types.assert(x, _ as 2|3)

    x = nil
]]


run[[
    local a: nil | 1

    if not not a then
        types.assert(a, _ as nil)
    end

    types.assert(a, _ as 1 | nil)
]]

run[[
    local x = 1

    do
        assert(math.random() > 0.5)

        x = 2
    end

    types.assert(x, 2)
]]

run[[
    if false then
    else
        local x = 1
        do
            types.assert(x, 1)
        end
    end
]]

run[[
    local bar

    if false then
    else
        local function foo()
            return 1
        end

        bar = function()
            return foo() + 1
        end
    end

    types.assert(bar(), 2)
]]

run[[
    local tbl = {} as {field = nil | {foo = true | false}}

    if tbl.field and tbl.field.foo then
        types.assert(tbl.field, _ as { foo = false | true })
    end
]]

run[[
    local tbl = {} as {foo = nil | {bar = 1337 | false}}

    if tbl.foo and tbl.foo.bar then
        types.assert(tbl.foo.bar, 1337)
    end
]]

pending[[
    local type Shape = { kind = "circle", radius = number } | { kind = "square", sideLength = number }

    local function area(shape: Shape): number
        if shape.kind == "circle" then 
            print(shape.radius)
        else
            print(shape.sideLength)
        end 
    end
]]

pending[[
    local a: nil | 1

    if not not not a then
        types.assert(a, _ as 1)
    end

    types.assert(a, _ as 1 | nil)
]]

pending[[
    local a: nil | 1

    if a or true and a or false then
        types.assert(a, _ as 1 | 1)
    end

    types.assert(a, _ as 1 | nil)
]]


pending[[

    local x: number
    
    if x >= 0 and x <= 10 then
        types.assert<|x, 0 .. 10|>
    end
]]

pending[[
    local x: -3 | -2 | -1 | 0 | 1 | 2 | 3

    if x >= 0 then
        types.assert<|x, 0|1|2|3|>
        if x >= 1 then
            types.assert<|x, 1|2|3|>
        end
    end
]]

pending[[
    local x: 1 | "1"
    local y = type(x) == "number"
    if y then
        types.assert(x, 1)
    else
        types.assert(x, "1")
    end
]]

pending[[
    local x: 1 | "1"
    local y = type(x) ~= "number"
    if y then
        types.assert(x, "1")
    else
        types.assert(x, 1)
    end
]]

pending[[
    local x: 1 | "1"
    local t = "number"
    local y = type(x) ~= t
    if y then
        types.assert(x, "1")
    else
        types.assert(x, 1)
    end
]]


pending[[
    local type T = {
        config = {
            extra_indent = nil | {
                [string] = "toggle"|{to=string},
            },
            preserve_whitespace = boolean | nil,
        }
    }

    local x = _ as string
    local t = {} as T


    if t.config.extra_indent then
        local lol = t.config.extra_indent
        print(t.config.extra_indent[x])
        print(lol[x])
    end
]]
run[[
    local META = {}
    META.__index = META
    type META.@Self = {parent = number | nil}
    function META:SetParent(parent : number | nil)
        if parent then
            self.parent = parent
        else
            -- test BaseType:UpvalueReference collision with object and upvalue
            types.assert(self.parent, _ as nil | number)
        end
    end
]]

run[[
    local x = ("lol"):byte(1,1 as 1 | 0)
    if not x then 
        error("lol")
    end

    types.assert(x, 108)
]]

run[[
    local x = _ as 1 | 2 | 3
    if x == 1 then return end
    types.assert(x, _ as 2 | 3)
    if x ~= 3 then return end
    types.assert(x, _ as 2)
    if x == 2 then return end
    error("dead code")
]]

run[[
    local x = _ as 1 | 2

    if x == 1 then
        types.assert(x, 1)
        return
    else
        types.assert(x, 2)
        return
    end
    
    error("shouldn't happen")
]]

run[[
    local lol
    if true then
        lol = {}
    end

    do
        if _ as boolean then
            lol.x = 1
        else
            lol.x = 2
        end

        local function get_files()
            types.assert(lol.x, _ as 1 | 2)
        end
    end
]]