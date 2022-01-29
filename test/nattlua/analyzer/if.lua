local T = require("test.helpers")
local run = T.RunCode

run([[
    local a = 1
    local function b(lol)
        if lol == 1 then return "foo" end
        return lol + 4, true
    end
    local d = b(2)
    attest.equal(d, 6)
    local d = b(a)
    attest.equal(d, "foo")
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

    attest.equal(a, false)
    attest.equal(b, true)
    attest.equal(c, "lol")
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
    attest.equal(a, _ as true | false)
]]

run[[
    local x = 0
    local MAYBE: true | false

    if MAYBE then
        x = 1
    end

    if MAYBE2 then
        attest.equal<|x, 0 | 1|>
        x = 2
    end

    if MAYBE then
        attest.equal<|x, 1 | 2|>
    end

]]

run([[
    -- assigning a value inside an uncertain branch
    local a = false

    if _ as any then
        attest.equal(a, false)
        a = true
        attest.equal(a, true)
    end
    attest.equal(a, _ as false | true)
]])

run([[
    -- assigning in uncertain branch and else part
    local a = false

    if _ as any then
        attest.equal(a, false)
        a = true
        attest.equal(a, true)
    else
        attest.equal(a, false)
        a = 1
        attest.equal(a, 1)
    end

    attest.equal(a, _ as true | 1)
]])

run([[
    local a: nil | 1

    if a then
        attest.equal(a, _ as 1)
    end

    attest.equal(a, _ as 1 | nil)
]])

run([[
    local a: nil | 1

    if a then
        attest.equal(a, _ as 1)
    else
        attest.equal(a, _ as nil)
    end

    attest.equal(a, _ as 1 | nil)
]])

run([[
    local a = 0

    if MAYBE then
        a = 1
    end
    attest.equal(a, _ as 0 | 1)
]])

run[[
    local a: nil | 1

    if a then
        attest.equal(a, _ as 1)
        if a then
            if a then
                attest.equal(a, _ as 1)
            end
            attest.equal(a, _ as 1)
        end
    end

    attest.equal(a, _ as 1 | nil)
]]

run([[
    local a: nil | 1

    if not a then
        attest.equal(a, _ as nil)
    end

    attest.equal(a, _ as 1 | nil)
]])

run[[
    local a: true | false

    if not a then
        attest.equal(a, false)
    else
        attest.equal(a, true)
    end
]]

run([[
    local a: number | string

    if type(a) == "number" then
        attest.equal(a, _ as number)
    end

    attest.equal(a, _ as number | string)
]])

run[[
    local a: 1 | false | true

    if type(a) == "boolean" then
        attest.equal(a, _ as boolean)
    end

    if type(a) ~= "boolean" then
        attest.equal(a, 1)
    else
        attest.equal(a, _ as boolean)
    end
]]

do
    _G.lol = nil

    run([[
        local type hit = analyzer function()
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

    attest.equal(c, 1)
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

    attest.equal(c, _ as -1 | 1)
]])


run[[
    local a = false

    attest.equal(a, false)

    if maybe then
        a = true
        attest.equal(a, true)
    end

    attest.equal(a, _ as true | false)
]]

run[[
    local a: true | false

    if a then
        attest.equal(a, true)
    else
        attest.equal(a, false)
    end

    if not a then
        attest.equal(a, false)
    else
        attest.equal(a, true)
    end

    if not a then
        if a then
            attest.equal("this should never be reached")
        end
    else
        if a then
            attest.equal(a, true)
        else
            attest.equal("unreachable code!!")
        end
    end
]]


run[[
    local a: nil | 1
        
    if a then
        attest.equal(a, _ as 1)
        if a then
            if a then
                attest.equal(a, _ as 1)
            end
            attest.equal(a, _ as 1)
        end
    end

    attest.equal(a, _ as 1 | nil)
]]

run[[
    local x: false | 1
    assert(not x)
    attest.equal(x, false)
]]

run[[
    local x: true | nil 
    attest.equal(assert(x), true)
    attest.equal(x, true)
]]

run[[
    local x: false | 1
    assert(x)
    attest.equal(x, 1)
]]

run[[
    local x: true | false
    
    if x then return end
    
    attest.equal(x, false)
]]

run[[
    local x: true | false
    
    if not x then return end
    
    attest.equal(x, true)
]]

run[[
    local c = 0

    if maybe then
        c = c + 1
    else
        c = c - 1
    end

    attest.equal(c, _ as -1 | 1)
]]

run([[
    local a: nil | 1
    if not a then return end
    attest.equal(a, 1)
]])

run([[
    local a: nil | 1
    if a then return end
    attest.equal(a, nil)
]])

run[[
    local a = true

    while maybe do
        a = false
    end

    attest.equal(a, _ as true | false)
]]

run[[
    local a = true

    for i = 1, 10 do
        a = false
    end

    attest.equal(a, _ as false)
]]

run[[
    local a = true

    for i = 1, _ as number do
        a = false
    end

    attest.equal(a, _ as true | false)
]]

run[[
    local a: {[string] = number}
    local b = true

    for k,v in pairs(a) do
        attest.equal(k, _ as string)
        attest.equal(v, _ as number)
        b = false
    end

    attest.equal(b, _ as true | false)
]]

run[[
    local a: {foo = number}
    local b = true

    for k,v in pairs(a) do
        b = false
    end

    attest.equal(b, _ as false)
]]

run([[
    local type a = {}

    if not a then
        -- shouldn't reach
        attest.equal(1, 2)
    else
        attest.equal(1, 1)
    end
]])

run([[
    local type a = {}
    if not a then
        -- shouldn't reach
        attest.equal(1, 2)
    end
]])

run[[
    local a: true | false | number | "foo" | "bar" | nil | 1

    if a then
        attest.equal(a, _ as true | number | "foo" | "bar" | 1)
    else
        attest.equal(a, _ as false | nil)
    end

    if not a then
        attest.equal(a, _ as false | nil)
    end

    if a == "foo" then
        attest.equal(a, "foo")
    end
]]

run[[
    local x: nil | true

    if not x then
        return
    end

    do
        do
            attest.equal(x, true)
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
    local MAYBE: function=()>(boolean)
    local x = 0
    if MAYBE() then x = x + 1 end -- 1
    if MAYBE() then x = x - 1 end -- -1 | 0
    attest.equal(x, _ as -1 | 0 | 1)
]]

run[[
    local x = 0
    if MAYBE then
        x = 1
    else
        x = -1
    end
    attest.equal(x, _ as -1 | 1)
]]

run[[
    local x = 0
    if MAYBE then
        x = 1
    end
    attest.equal(x, _ as 0 | 1)
]]

run[[
    x = 1

    if MAYBE then
        x = 2
    end

    if MAYBE then
        x = 3
    end

    attest.equal(x, _ as 1|2|3)

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

    attest.equal(foo, true)
]]

run[[
    local x = 1

    if MAYBE then
        if true then
            x = 2
        end
    end

    attest.equal(x, _ as 1 | 2)
]]

run[[
    local x = 1

    if false then
        
    else
        x = 2
    end

    attest.equal(x, _ as 2)
]]

run[[
    local x = 1

    if MAYBE then
        x = 2
    end

    if MAYBE then
        x = 3
    end

    attest.equal(x, _ as 1 | 2 | 3)
]]


run[[
    --DISABLE_CODE_RESULT

    local x = 1

    if MAYBE then
        attest.equal<|x, 1|>
        x = 2
        attest.equal<|x, 2|>
    elseif MAYBE then
        attest.equal<|x, 1|>
        x = 3
        attest.equal<|x, 3|>
    elseif MAYBE then
        attest.equal<|x, 1|>
        x = 4
        attest.equal<|x, 4|>
    end

    attest.equal<|x, 1 | 2 | 3 | 4|>
]]

run[[
    local foo = false

    if MAYBE then
        foo = true
    end
    if not foo then
        return
    end

    attest.equal(foo, true)
]]


run[[
    local x = 1
    attest.equal<|x, 1|>
]]

run[[
    local x = 1
    do
        attest.equal<|x, 1|>
    end
]]

run[[
    local x = 1
    x = 2
    attest.equal<|x, 2|>
]]

run[[
    local x = 1
    if true then
        x = 2
    end
    attest.equal<|x, 2|>
]]

run[[
    local x = 1
    if MAYBE then
        x = 2
    end
    attest.equal<|x, 1 | 2|>
]]

run[[
    local x = 1
    if MAYBE then
        attest.equal<|x, 1|>
        x = 2
        attest.equal<|x, 2|>
    end
    attest.equal<|x, 1|2|>
]]

run[[
    local x = 1

    if math.random() > 0.5 then
        x = 2
        attest.equal<|x, 2|>
    else
        attest.equal<|x, 1|>
        x = 3
    end
    attest.equal<|x, 2 | 3|>
]]

run[[
    local x = 1

    if math.random() > 0.5 then
        x = 2
    elseif math.random() > 0.5 then
        x = 3
    elseif math.random() > 0.5 then
        x = 4
    end

    attest.equal<|x, 1|2|3|4|>
]]

run[[
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

    attest.equal<|x, 5|2|3|4|>
]]


run([[
    local x = 1

    if x == 1 then
        x = 2
    end

    if x == 2 then
        x = 3
    end

    attest.equal<|x, 3|>
]])


run[[
    local x: -1 | 0 | 1 | 2 | 3
    local y = x >= 0 and x or nil
    attest.equal<|y, 0 | 1 | 2 | 3 | nil|>

    local y = x >= 0 and x >= 1 and x or nil
    attest.equal<|y, 1 | 2 | 3 | nil|>
]]

run[[
    local function test(LOL)
        attest.equal(LOL, "str")
    end
    
    local x: 1 | "str"
    if x == 1 or test(x) then
    
    end
]]

run[[
    local function test(LOL)
        attest.equal(LOL, 1)
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
    
    attest.equal<|y, 1 | true|>
]]

run[[
    local a = {}
    if MAYBE then
        a.lol = true
        attest.equal(a.lol, true)
    end
    attest.equal(a.lol, _ as nil | true)
]]

run[[
    if _ as boolean then
        local function foo() 
            local c = {}
            c.foo = true
            
            if _ as boolean then
                local function test()
                    local x = c.foo
                    attest.equal(x, true)
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
        attest.equal(tbl.foo, 2)
    end
    
    attest.equal(tbl.foo, _ as 1 | 2)
]]

run[[
    local tbl = {foo = {bar = 1}}

    if MAYBE then
        tbl.foo.bar = 2
        attest.equal(tbl.foo.bar, 2)
    end

    attest.equal(tbl.foo.bar, _ as 1 | 2)
]]

run[[
    local x: {
        field = number | nil,
    } = {}
    
    if MAYBE then
        x.field = nil
        attest.equal(x.field, nil)
    end
    attest.equal(x.field, _ as number | nil)
]]

run[[
    local x = { lol = _ as false | 1 }
    if not x.lol then
        if MAYBE then
            x.lol = 1 
        end
    end
    attest.equal(x.lol, _ as false | 1)
]]

run[[
    assert(maybe)

    local y = 1

    local function foo()
        local x = 1
        return 1
    end    

    attest.equal(foo(), 1)
]]

run[[
    local function lol()
        if MAYBE then
            return 1
        end
    end
    
    local x = lol()
    
    attest.equal<|x, 1 | nil|>
]]

run[[
    --DISABLE_CODE_RESULT

    local type HeadPos = {
        findheadpos_head_bone = number | false,
        findheadpos_head_attachment = number | nil,
        findheadpos_last_mdl = string | nil,
        @Name = "BlackBox",
    }

    local function FindHeadPosition(ent: mutable HeadPos)
        
        if MAYBE then
            ent.findheadpos_head_bone = false
        end
        
        if ent.findheadpos_head_bone then

        else
            if not ent.findheadpos_head_attachment then
                ent.findheadpos_head_attachment = _ as nil | number 
            end

            attest.equal<|ent.findheadpos_head_attachment, nil | number|>
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
    
    attest.equal(x, _ as "test" | "foo")
]]

run[[
    local x: {foo = nil | 1}

    if x.foo then
        attest.equal(x.foo, 1)
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

    attest.equal(x, _ as 2 | 3 | 4)
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
    attest.equal(x(), _ as 1 | 2 | 3)
]]

run[[
    local x

    if _ as boolean then
        x = 1
    else
        x = 2
    end

    attest.equal(x, _ as 1 | 2)

    local function lol()
        attest.equal(x, _ as 1 | 2)
    end

    lol()
]]

run[[
    if math.random() > 0.5 then
        FOO = 1
    
        attest.equal(FOO, 1)
        
        do
            attest.equal(FOO, 1)
        end
    end
]]

run[[
    assert(math.random() > 0.5)

    LOL = true

    if math.random() > 0.5 then end

    attest.equal(LOL, true)
]]

run[[
    local foo = {}
    assert(math.random() > 0.5)

    foo.bar = 1

    if math.random() > 0.5 then end

    attest.equal(foo.bar, 1)
]]

run[[
    local foo = 1

    assert(_ as boolean)

    if _ as boolean then
        foo = 2

        if _ as boolean then
            local a = 1
        end

        attest.equal(foo, 2)
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

        attest.equal(foo, 2)
    end
]]

run[[
    local function test(x: ref any)
        attest.equal(x, true)
        return true
    end
    
    local function foo(x: {foo = boolean | nil}) 
        if x.foo and test(x.foo) then
            attest.equal(x.foo, true)
        end
    end
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

    attest.equal(x, _ as 2|3)

    x = nil
]]


run[[
    local a: nil | 1

    if not not a then
        attest.equal(a, _ as nil)
    end

    attest.equal(a, _ as 1 | nil)
]]

run[[
    local x = 1

    do
        assert(math.random() > 0.5)

        x = 2
    end

    attest.equal(x, 2)
]]

run[[
    if false then
    else
        local x = 1
        do
            attest.equal(x, 1)
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

    attest.equal(bar(), 2)
]]

run[[
    local tbl = {} as {field = nil | {foo = true | false}}

    if tbl.field and tbl.field.foo then
        attest.equal(tbl.field, _ as { foo = false | true })
    end
]]


run[[
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
        attest.equal(t.config.extra_indent[x], lol[x])
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
            attest.equal(self.parent, _ as nil | number)
        end
    end
]]


run[[
    local x = _ as 1 | 2 | 3
    if x == 1 then return end
    attest.equal(x, _ as 2 | 3)
    if x ~= 3 then return end
    attest.equal(x, _ as 2)
    if x == 2 then return end
    error("dead code")
]]

run[[
    local x = _ as 1 | 2

    if x == 1 then
        attest.equal(x, 1)
        return
    else
        attest.equal(x, 2)
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
            attest.equal(lol.x, _ as 1 | 2)
        end
    end
]]

run[[
    -- mutation tracking for wide key
    local operators = {
        ["+"] = 1,
        ["-"] = -1,
        [">"] = 1,
        ["<"] = -1
    }
    local i = 0
    local op = "" as string

    if operators[op] then
        attest.equal(operators[op], _ as -1 | 1)
        i = operators[op]
    end

    attest.equal(i, _ as -1 | 0 | 1)
]]

run[[
    local ffi = require("ffi")

    do
        local C

        -- make sure C is not C | nil because it's assigned to the same value in both branches

        if ffi.os == "Windows" then
            C = assert(ffi.load("ws2_32"))
        else
            C = ffi.C
        end
        
        do 
            attest.equal(C, _ as ffi.C)
        end
    end
]]

run[=[
    local ffi = require("ffi")

    local x: boolean
    if x == true then
        error("LOL")
    end
    
    attest.equal(x, false)
    
    ffi.cdef[[
        void strerror(int errnum);
    ]]
    
    if ffi.os == "Windows" then
        local x = ffi.C.strerror
        attest.equal(x, _ as function=(number)>(nil))
    end
]=]

run[=[
    local ffi = require("ffi")

    if math.random() > 0.5 then
        ffi.cdef[[
            uint32_t FormatMessageA(
                uint32_t dwFlags,
            );
        ]]
        
        do
            if math.random() > 0.5 then
                ffi.C.FormatMessageA(1)
            end
        end
    
        if math.random() > 0.5 then
            ffi.C.FormatMessageA(1)
        end
    end
]=]

run[[
    local function foo(x: any)
        if type(x) == "string" then
            § SCOPE1 = analyzer:GetScope()
            x = 1
        elseif type(x) == "number" then
            § assert(not analyzer:GetScope():IsCertainFromScope(SCOPE1))
            x = 2
        elseif type(x) == "table" then
            § assert(not analyzer:GetScope():IsCertainFromScope(SCOPE1))
            x = 3
        end
    
        § SCOPE1 = nil
    end
]]

run[[
    local val: any

    if type(val) == "boolean" then
        val = ffi.new("int[1]", val and 1 or 0)
    elseif type(val) == "number" then
        val = ffi.new("int[1]", val)
    elseif type(val) ~= "cdata" then
        error("uh oh")
    end
    
    attest.equal(val, _ as any | {[number] = number})
]]

run([[
    local function foo(b: true)
        if b then
    
        end
    end
]], nil, "if condition is always true")
run([[
    local function foo(b: false)
        if false then
    
        end
    end
]], nil, "if condition is always false")

run([[
    local function foo(b: false)
        if b then
    
        else
    
        end
    end
]], nil, "else part of if condition is always true")

run[[
    local function foo(b: literal ref boolean)
        if b then

        end
    end

    foo(true)
    foo(false)
    
    §assert(#analyzer.diagnostics == 0)
]]

run[[
    --local type print = any
    local ffi = require("ffi")

    do
        local C

        if ffi.os == "Windows" then
            C = assert(ffi.load("ws2_32"))
        else
            C = ffi.C
        end

        if ffi.os == "OSX" then
        elseif ffi.os == "Windows" then
        else -- posix
        end

        attest.equal(ffi.os == "Windows", _ as true | false)
    end
]]

run([[
    local function foo(x: literal ref (nil | boolean))
        if x then
    
        end
    end
    
    foo()
    foo(true)
    foo(false)

    §assert(#analyzer.diagnostics == 0)
]])

run[[
    local function foo(x: literal ref (nil | boolean))
        if x == false then
    
        end
    end
    
    foo()
    foo(true)
    foo(false)

    §assert(#analyzer.diagnostics == 0)
]]

run[[
    local function foo(x: literal ref (nil | boolean))
        if x == false then
    
        elseif x then
    
        else
    
        end
    end
    
    foo()
    foo(true)
    foo(false)

    §assert(#analyzer.diagnostics == 0)
]]

run[[
    local test
    local function foo()
        test()
    end

    test = function()
        if jit.os == "Linux" then
            return true
        end
    end
]]

run[[
    local x: string | {} | nil

    if x then
        if type(x) == "table" then
            attest.equal(x, {})
        end
    end
]]


run[[
    local x: -3 | -2 | -1 | 0 | 1 | 2 | 3

    if x >= 0 then
        attest.equal<|x, 0|1|2|3|>
        if x >= 1 then
            attest.equal<|x, 1|2|3|>
        end
    end
]]

pending[[
    local x: true | false | 2

    if x then    
        attest.equal(x, _ as true | 2)
        x = 1
    end

    attest.equal<|x, true | false | 2 | 1|>
]]
pending[[
    local x = 1

    if MAYBE then
        attest.equal<|x, 1|>
        x = 1.5
        attest.equal<|x, 1.5|>
        x = 1.75
        attest.equal<|x, 1.75|>
        if MAYBE then
            x = 2
            if MAYBE then
                x = 2.5
            end
            attest.equal<|x, 2 | 2.5|>
        end
        x = 3
        attest.equal<|x, 3|>
    end
    
    attest.equal<|x, 1 | 3|>
]]


pending[[
    local x = 1

    if math.random() > 0.5 then
        if true then
            do
                x = 1337
            end
        end
        attest.equal<|x, 1337|>
        x = 2
        attest.equal<|x, 2|>
    else
        attest.equal<|x, 1|>
        x = 66
    end
    
    attest.equal<|x, 1 | 2|>
]]

pending[[
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

    attest.equal<|x, 1337 | 0 | 1 | 3 | 4|>
]]

pending[[
    elseif MAYBE then
        attest.equal<|x, 1|>
        x = 3
        attest.equal<|x, 3|>
    elseif MAYBE then
        attest.equal<|x, 1|>
        x = 4
        attest.equal<|x, 4|>
    else
        attest.equal<|x, 1|>
        x = 5
        attest.equal<|x, 5|>
    end

    print(x)

    --attest.equal<|x, 1 | 2 | 3 | 4|>
]]
pending([[
    local a: nil | 1

    if not a or true and a or false then
        attest.equal(a, _ as 1 | nil)
    end

    attest.equal(a, _ as 1 | nil)
]])

pending[[
    local MAYBE: boolean
    local x = 0
    if MAYBE then x = x + 1 end -- 1
    if MAYBE then x = x - 1 end -- 0
    attest.equal(x, 0)
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

    if not not a then
        attest.equal(a, _ as 1)
    end

    attest.equal(a, _ as 1 | nil)
]]

pending[[
    local a: nil | 1

    if a or true and a or false then
        attest.equal(a, _ as 1 | 1)
    end

    attest.equal(a, _ as 1 | nil)
]]


pending[[

    local x: number
    
    if x >= 0 and x <= 10 then
        attest.equal<|x, 0 .. 10|>
    end
]]


pending[[
    local x: 1 | "1"
    local y = type(x) == "number"
    if y then
        attest.equal(x, 1)
    else
        attest.equal(x, "1")
    end
]]

pending[[
    local x: 1 | "1"
    local y = type(x) ~= "number"
    if y then
        attest.equal(x, "1")
    else
        attest.equal(x, 1)
    end
]]

pending[[
    local x: 1 | "1"
    local t = "number"
    local y = type(x) ~= t
    if y then
        attest.equal(x, "1")
    else
        attest.equal(x, 1)
    end
]]
