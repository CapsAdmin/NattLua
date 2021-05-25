local T = require("test.helpers")
local run = T.RunCode
run[[
    local function test(a,b): nil

    end

    test(true, true)
    test(false, false)

    type_assert(test, _ as (function(a: false|true|any, b: false|true|any): nil))
]]
run[[
    local function test(a: any,b: any): nil

    end

    test(true, true)
    test(false, false)

    type_assert(test, _ as (function(a: any, b: any): nil))
]]


do -- assignment
    run[[
        local a
        type_assert(a, nil)
    ]]

    run[[
        local a: boolean
        type_assert(a, _ as boolean)
    ]]


    run[[
        a = nil
        -- todo, if any calls don't happen here then it's probably nil?
        type_assert(a, _ as nil)
    ]]

    run[[
        local a = {}
        a[5] = 5
        type_assert(a[5], 5)
    ]]



    run[[
        local function test(...)
            return 1,2,...
        end

        local a,b,c = test(3)

        type_assert(a,1)
        type_assert(b,2)
        type_assert(c,3)
    ]]

    run[[
        local a, b, c
        a, b, c = 0, 1
        type_assert(a, 0)
        type_assert(b, 1)
        type_assert(c, nil)
        a, b = a+1, b+1, a+b
        type_assert(a, 1)
        type_assert(b, 2)
        a, b, c = 0
        type_assert(a, 0)
        type_assert(b, nil)
        type_assert(c, nil)
    ]]

    run[[
        a, b, c = 0, 1
        type_assert(a, 0)
        type_assert(b, 1)
        type_assert(c, nil)
        a, b = a+1, b+1, a+b
        type_assert(a, 1)
        type_assert(b, 2)
        a, b, c = 0
        type_assert(a, 0)
        type_assert(b, nil)
        type_assert(c, nil)
    ]]
    run[[
        local a = {}
        local i = 3

        i, a[i] = i+1, 20

        type_assert(i, 4)
        type_assert(a[3], 20)
    ]]
    run[[
        a = {}
        i = 3
        i, a[i] = i+1, 20
        type_assert(i, 4)
        type_assert(a[3], 20)
    ]]
end
run[[
    local z1, z2
    local function test(i)
        local function f() return i end
        z1 = z1 or f
        z2 = f
    end

    test(1)
    test(2)

    --type_assert(z1(), 1)
    type_assert(z2(), 2)
]]

--local numbers = {-1,-0.5,0,0.5,1,math.huge,0/0}

run"type_assert(1, 1)"
run"type_assert(-1, -1)"
run"type_assert(-0.5, -0.5)"
run"type_assert(0, 0)"

--- exp
run[[
    type_assert(1e5, 100000)
    type_assert(1e+5, 100000)
    type_assert(1e-5, 0.00001)
]]

--- hex exp +hexfloat !lex
run[[
    type_assert(0xe+9, 23)
    type_assert(0xep9, 7168)
    type_assert(0xep+9, 7168)
    type_assert(0xep-9, 0.02734375)
]]

run"type_assert(1-1, 0)"
run"type_assert(1+1, 2)"
run"type_assert(2*3, 6)"
run"type_assert(2^3, 8)"
run"type_assert(3%3, 0)"
run"type_assert(-1*2, -2)"
run"type_assert(1/2, 0.5)"
run"type_assert(1/2, 0.5)"
run"type_assert(0b10 | 0b01, 0b11)"
run"type_assert(0b10 & 0b10, 0b10)"
run"type_assert(0b10 & 0b10, 0b10)"

--R"type_assert(0b10 >> 1, 0b01)"
--R"type_assert(0b01 << 1, 0b10)"
--R"type_assert(~0b01, -2)"
run"type_assert('a'..'b', 'ab')"
run"type_assert('a'..'b'..'c', 'abc')"
run"type_assert(1 .. '', nil as '1')"
run"type_assert('ab'..(1)..'cd'..(1.5), 'ab1cd1.5')"


run[[ --- tnew
    local a = nil
    local b = {}
    local t = {[true] = a, [false] = b or 1}
    type_assert(t[true], nil)
    type_assert(t[false], b)
]]
run[[ --- tdup
    local b = {}
    local t = {[true] = nil, [false] = b or 1}
    type_assert(t[true], nil)
    type_assert(t[false], b)
]]

run[[
    do --- tnew
        local a = nil
        local b = {}
        local t = {[true] = a, [false] = b or 1}
        
        type_assert(t[true], nil)
        type_assert(t[false], b)
    end

    do --- tdup
        local b = {}
        local t = {[true] = nil, [false] = b or 1}
        type_assert(t[true], nil)
        type_assert(t[false], b)
    end
]]
run[[
    local a = 1
    type_assert(a, nil as 1)
]]
run[[
    local a = {a = 1}
    type_assert(a.a, nil as 1)
]]
run[[
    local a = {a = {a = 1}}
    type_assert(a.a.a, nil as 1)
]]
run[[
    local a = {a = 1}
    a.a = nil
    type_assert(a.a, nil)
]]
run[[
    local a = {}
    a.a = 1
    type_assert(a.a, nil as 1)
]]
run[[
    local a = ""
    type_assert(a, nil as "")
]]
run[[
    local type a = number
    type_assert(a, _ as number)
]]
run[[
    local a
    a = 1
    type_assert(a, 1)
]]
run[[
    local a = {}
    a.foo = {}

    local c = 0

    function a:bar()
        type_assert(self, a)
        c = 1
    end

    a:bar()

    type_assert(c, 1)
]]
run[[
    local function test()

    end

    type_assert(test, nil as function():)
]]
run[[
    local a = 1
    repeat
        type_assert(a, 1)
    until false
]]
run[[
    local c = 0
    for i = 1, 10, 2 do
        type_assert_superset(i, nil as number)
        if i == 1 then
            c = 1
            break
        end
    end
    type_assert(c, _ as 1)
]]
run[[
    local a = 0
    while false do
        a = 1
    end
    type_assert(a, 0)
]]
run[[
    local function lol(a,b,c)
        if true then
            return a+b+c
        elseif true then
            return true
        end
        a = 0
        return a
    end
    local a = lol(1,2,3)

    type_assert(a, 6)
]]
run[[
    local a = 1+2+3+4
    local b = nil

    local function foo(foo)
        return foo
    end

    if a then
        b = foo(a+10)
    end

    type_assert(b, 20)
    type_assert(a, 10)
]]
run[[
    b = {}
    b.lol = 1

    local a = b

    local function foo(tbal)
        return tbal.lol + 1
    end

    local c = foo(a)

    type_assert(c, 2)
]]
run[[
    local META = {}
    META.__index = META

    function META:Test(a,b,c)
        return 1+c,2+b,3+a
    end

    local a,b,c = META:Test(1,2,3)
]]
run[[
    local function test(a)
        if a then
            return 1
        end

        return false
    end

    local res = test(true)

    if res then
        local a = 1 + res

        type_assert(a, 2)
    end
]]
run[[
    local a = 1337
    for i = 1, a do
        type_assert(i, 1)
        if i == 15 then
            a = 7777
            break
        end
    end
    type_assert(a, _ as 1337 | 7777)
]]
run[[
    local function lol(a, ...)
        local lol,foo,bar = ...

        if a == 1 then return 1 end
        if a == 2 then return {} end
        if a == 3 then return "", foo+2,3 end
    end

    local a,b,c = lol(3,1,2,3)

    type_assert(a, "")
    type_assert(b, 4)
    type_assert(c, 3)
]]
run[[
    function foo(a, b) return a+b end

    local a = foo(1,2)

    type_assert(a, 3)
]]
run[[
local a = {b = {c = {}}}
a.b.c = 1
]]
run[[
    local a = function(b)
        if b then
            return true
        end
        return 1,2,3
    end

    a()
    a(true)

]]
run[[
    function aaa(ok)
        if ok then
            return 2
        else
            return "hello"
        end
    end

    aaa(true)
    local ag = aaa(false)

    type_assert(ag, "hello")

]]
run[[
    local foo = {lol = 30}
    function foo:bar(a)
        return a+self.lol
    end

    type_assert(foo:bar(20), 50)

]]
run[[
    function prefix (w1, w2)
        return w1 .. ' ' .. w2
    end

    type_assert(prefix("hello", "world"), "hello world")
]]
run[[
    local func = function()
        local a = 1

        return function()
            return a
        end
    end

    local f = func()

    type_assert(f(), 1)
]]
run[[
    function prefix (w1, w2)
        return w1 .. ' ' .. w2
    end

    local w1,w2 = "foo", "bar"
    local statetab = {["foo bar"] = 1337}

    local test = statetab[prefix(w1, w2)]
    type_assert(test, 1337)
]]
run[[
    local function test(a)
        --if a > 10 then return a end
        return test(a+1)
    end

    type_assert(test(1), nil as any)
]]
run[[
    local function test(a): number
        if a > 10 then return a end
        return test(a+1)
    end

    type_assert(test(1), nil as number)
]]
run[[
    local a: string | number = 1

    local type test = function(a: number, b: string): boolean, number

    local foo,bar = test(1, "")

    type_assert(foo, nil as boolean)
    type_assert(bar, nil as number)
]]
run[[
    local type lol = number

    local type math = {
        sin = (function(a: lol, b: string): lol),
        cos = (function(a: string): lol),
        cos = (function(a: number): lol),
    }

    type math.lol = (function(): lol)

    local a = math.sin(1, "")
    local b = math.lol() -- support overloads

    type_assert(a, nil as number)
    type_assert(b, nil as number)

    type math.lol = nil
]]
run[[
    local type foo = {
        a = number,
        b = {
            str = string,
        }
    }

    local b: foo = {a=1, b={str="lol"}}
    local c = b.a
    local d = b.b.str

    subset_of(b, _ as foo)
]]
run[[
  --  local a: (string|number)[] = {"", ""}
  --  a[1] = ""
  --  a[2] = 1
]]
run[[
    local type foo = {
        bar = (function(a: boolean, b: number): true) | (function(a: number): false),
    }

    local a = foo.bar(true, 1)
    local b = foo.bar(1)

    type_assert(a, nil as true)
    type_assert(b, nil as false)
]]
run[[
    local a: string = "1"
    local type a = string | number | (boolean | string)

    local type type_func = function(a: any,b: any,c: any) return types.String(), types.Number() end
    local a, b = type_func(a,2,3)
    type_assert(a, _ as string)
    type_assert(b, _ as number)
]]

--[[

    for i,v in ipairs({"LOL",2,3}) do
        if i == 1 then
            print(i,v)
            type_assert(i, _ as 1)
            type_assert(v, _ as "LOL")
        end
    end
]]
run[[
    local a = {
        foo = true,
        bar = false,
        a = 1,
        lol = {},
    }

    local k, v = next(a)
]]
run[[
    local a: _G.string

    type_assert(a, _G.string)
]]
run[[
    local a = ""

    if a is string then
        type_assert(a, _ as "")
    end

]]
run[[
    local a = math.cos(_ as number)
    type_assert(a, nil as number)

    if a is number then
        type_assert(a, _ as number)
    end
]]
run[[
    local type math = {
        sin = function(number): number
    }

    local type old = math.cos
    type math.cos = function(number): number

    local a = math.sin(1)

    type_assert(a, _ as number)

    type math.cos = old
]]

run[[
    local type a = function()
        _G.LOL = true
    end

    local type b = function()
        _G.LOL = nil
        local t = analyzer:GetLocalOrEnvironmentValue(types.Literal("a"), "typesystem")
        local func = t:GetData().lua_function
        func()
        if not _G.LOL then
            error("test fail")
        end
    end

    local a = b()
]]
run[[
    a: number = (lol as function(): number)()

    type_assert(a, nil as number)
]]
run[[
    local a = {}
    a.b: boolean, a.c: number = LOL as any, LOL2 as any
]]
run[[
    local type test = {
        sin = (function(number): number),
        cos = (function(number): number),
    }

    local a = test.sin(1)
]]
run[[
    local type lol = function(a: string) return a end
    local a: lol<|string|>
    type_assert(a, _ as string)
]]
run[[
    local a = {}
    function a:lol(a,b,c)
        return a+b+c
    end
    type_assert(a:lol(1,2,3), 6)
]]
run[[
    local a = {}
    function a.lol(_, a,b,c)
        return a+b+c
    end
    type_assert(a:lol(1,2,3), 6)
]]
run[[
    local a = {}
    function a.lol(a,b,c)
        return a+b+c
    end
    type_assert(a.lol(1,2,3), 6)
]]
run[[
    local a = {}
    function a.lol(...)
        local a,b,c = ...
        return a+b+c
    end
    type_assert(a.lol(1,2,3), 6)
]]
run[[
    local a = {}
    function a.lol(foo, ...)
        local a,b,c = ...
        return a+b+c+foo
    end
    type_assert(a.lol(10,1,2,3), 16)
]]
run[[
    local a = (function(...) return ...+... end)(10)
]]
run[[
    -- this will error with not defined
    --type_assert(TOTAL_STRANGER_COUNT, _ as number)
    --type_assert(TOTAL_STRANGER_STRING, _ as string)
]]
run[[
    local a = b as any
    local b = 2
    type_assert(a, _ as any)
]]
run[[
    local type function identity(a)
        return a
    end
]]
run[[
    local a = 1
    while true do
        a = a + 1
    end
    local b = a

    repeat
        b = b + 1
    until true

    local c = b
]]
pending[[
    for k,v in next, {1,2,3} do
        type_assert(_ as 1 | 2 | 3, _ as 1 | 2 | 3)
    end
]]
run[[
    local a = {a = self}
]]
run[[
    local a = setmetatable({} as {num = number}, meta)

    type_assert(a.num, _ as number)
]]
run[[

    local a,b,c = string.match("1 2 3", "(%d) (%d) (%d)")
    type_assert(a, nil as "1")
    type_assert(b, nil as "2")
    type_assert(c, nil as "3")

]]
run[[
    local def,{a,b,c} = {a=1,b=2,c=3}
    type_assert(a, 1)
    type_assert(b, 2)
    type_assert(c, 3)
    type_assert(def, def)
]]
run[[
    -- local a = nil
    -- local b = a and a.b or 1
 ]]
run[[
    local tbl = {} as {[true] = false}
    tbl[true] = false
    type_assert(tbl[true], false)
 ]]
run[[
    local tbl = {} as {1,true,3}
    tbl[1] = 1
    tbl[2] = true
 ]]
run[[
    local tbl: {1,true,3} = {1, true, 3}
    tbl[1] = 1
    tbl[2] = true
    tbl[3] = 3
 ]]
run[[
    local tbl: {1,true,3} = {1, true, 3}
    tbl[1] = 1
    tbl[2] = true
    tbl[3] = 3
 ]]
run[[
    local pl = {IsValid = function(self) end}
    local a = pl:IsValid()
    type_assert(a, nil)
 ]]
run[[
    local tbl = {}
    local test = "asdawd"
  --  tbl[test] = tbl[test] or {} TODO
    tbl[test] = "1"
    type_assert(tbl[test], nil as "1")
]]
run[[
    local function fill(t)
        for i = 1, 10 do
            t[i] = i
        end
    end
    local tbl = {}
    fill(tbl)
]]
run[[
    tbl, {a,b} = {a=1,b=2}

    type_assert(tbl.a, nil as 1)
    type_assert(tbl.b, nil as 2)
    type_assert(a, nil as 1)
    type_assert(b, nil as 2)
]]
run[[
    local type a = 1
    type_assert(a, 1)
]]
run[[
    local a = function(): number,string return 1,"" end
]]
run[[
    assert(1 == 1, "lol")
]]
run[[
    local function test(a, b)

    end

    test(true, false)
    test(false, true)
    test(1, "")

    local type function check(func: any, other)
        local a = func:GetArguments():Get(1)     -- this is being crawled for some reason
        local b = types.Union({
            types.Number(1),
            types.False(),
            types.True()
        })

        assert(b:IsSubsetOf(a))
    end

    check(test, "!")
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

