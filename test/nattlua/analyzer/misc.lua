local T = require("test.helpers")
local run = T.RunCode
run[[
    local function test(a,b): nil

    end

    test(true, true)
    test(false, false)

    types.assert(test, _ as function=(a: false|true|any, b: false|true|any)>(nil))
]]
run[[
    local function test(a: any,b: any): nil

    end

    test(true, true)
    test(false, false)

    types.assert(test, _ as function=(a: any, b: any)>(nil))
]]


do -- assignment
    run[[
        local a
        types.assert(a, nil)
    ]]

    run[[
        local a: boolean
        types.assert(a, _ as boolean)
    ]]


    run[[
        a = nil
        -- todo, if any calls don't happen here then it's probably nil?
        types.assert(a, _ as nil)
    ]]

    run[[
        local a = {}
        a[5] = 5
        types.assert(a[5], 5)
    ]]



    run[[
        local function test(...)
            return 1,2,...
        end

        local a,b,c = test(3)

        types.assert(a,1)
        types.assert(b,2)
        types.assert(c,3)
    ]]

    run[[
        local a, b, c
        a, b, c = 0, 1
        types.assert(a, 0)
        types.assert(b, 1)
        types.assert(c, nil)
        a, b = a+1, b+1, a+b
        types.assert(a, 1)
        types.assert(b, 2)
        a, b, c = 0
        types.assert(a, 0)
        types.assert(b, nil)
        types.assert(c, nil)
    ]]

    run[[
        a, b, c = 0, 1
        types.assert(a, 0)
        types.assert(b, 1)
        types.assert(c, nil)
        a, b = a+1, b+1, a+b
        types.assert(a, 1)
        types.assert(b, 2)
        a, b, c = 0
        types.assert(a, 0)
        types.assert(b, nil)
        types.assert(c, nil)
    ]]
    run[[
        local a = {}
        local i = 3

        i, a[i] = i+1, 20

        types.assert(i, 4)
        types.assert(a[3], 20)
    ]]
    run[[
        a = {}
        i = 3
        i, a[i] = i+1, 20
        types.assert(i, 4)
        types.assert(a[3], 20)
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

    --types.assert(z1(), 1)
    types.assert(z2(), 2)
]]

--local numbers = {-1,-0.5,0,0.5,1,math.huge,0/0}

run"types.assert(1, 1)"
run"types.assert(-1, -1)"
run"types.assert(-0.5, -0.5)"
run"types.assert(0, 0)"

--- exp
run[[
    types.assert(1e5, 100000)
    types.assert(1e+5, 100000)
    types.assert(1e-5, 0.00001)
]]

--- hex exp +hexfloat !lex
run[[
    types.assert(0xe+9, 23)
    types.assert(0xep9, 7168)
    types.assert(0xep+9, 7168)
    types.assert(0xep-9, 0.02734375)
]]

run"types.assert(1-1, 0)"
run"types.assert(1+1, 2)"
run"types.assert(2*3, 6)"
run"types.assert(2^3, 8)"
run"types.assert(3%3, 0)"
run"types.assert(-1*2, -2)"
run"types.assert(1/2, 0.5)"
run"types.assert(1/2, 0.5)"
run"types.assert(0b10 | 0b01, 0b11)"
run"types.assert(0b10 & 0b10, 0b10)"
run"types.assert(0b10 & 0b10, 0b10)"

--R"types.assert(0b10 >> 1, 0b01)"
--R"types.assert(0b01 << 1, 0b10)"
--R"types.assert(~0b01, -2)"
run"types.assert('a'..'b', 'ab')"
run"types.assert('a'..'b'..'c', 'abc')"
run"types.assert(1 .. '', nil as '1')"
run"types.assert('ab'..(1)..'cd'..(1.5), 'ab1cd1.5')"


run[[ --- tnew
    local a = nil
    local b = {}
    local t = {[true] = a, [false] = b or 1}
    types.assert(t[true], nil)
    types.assert(t[false], b)
]]
run[[ --- tdup
    local b = {}
    local t = {[true] = nil, [false] = b or 1}
    types.assert(t[true], nil)
    types.assert(t[false], b)
]]

run[[
    do --- tnew
        local a = nil
        local b = {}
        local t = {[true] = a, [false] = b or 1}
        
        types.assert(t[true], nil)
        types.assert(t[false], b)
    end

    do --- tdup
        local b = {}
        local t = {[true] = nil, [false] = b or 1}
        types.assert(t[true], nil)
        types.assert(t[false], b)
    end
]]
run[[
    local a = 1
    types.assert(a, nil as 1)
]]
run[[
    local a = {a = 1}
    types.assert(a.a, nil as 1)
]]
run[[
    local a = {a = {a = 1}}
    types.assert(a.a.a, nil as 1)
]]
run[[
    local a = {a = 1}
    a.a = nil
    types.assert(a.a, nil)
]]
run[[
    local a = {}
    a.a = 1
    types.assert(a.a, nil as 1)
]]
run[[
    local a = ""
    types.assert(a, nil as "")
]]
run[[
    local type a = number
    types.assert(a, _ as number)
]]
run[[
    local a
    a = 1
    types.assert(a, 1)
]]
run[[
    local a = {}
    a.foo = {}

    local c = 0

    function a:bar()
        types.assert(self, a)
        c = 1
    end

    a:bar()

    types.assert(c, 1)
]]
run[[
    local function test()

    end

    types.assert(test, nil as function=()>())
]]
run[[
    local c = 0
    for i = 1, 10, 2 do
        types.assert_superset(i, nil as number)
        if i == 1 then
            c = 1
            break
        end
    end
    types.assert(c, _ as 1)
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

    types.assert(a, 6)
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

    types.assert(b, 20)
    types.assert(a, 10)
]]
run[[
    b = {}
    b.lol = 1

    local a = b

    local function foo(tbal)
        return tbal.lol + 1
    end

    local c = foo(a)

    types.assert(c, 2)
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

        types.assert(a, 2)
    end
]]
pending[[
    local a = 1337
    for i = 1, a do
        types.assert(i, 1)
        if i == 15 then
            a = 7777
            break
        end
    end
    types.assert(a, _ as 1337 | 7777)
]]
run[[
    local function lol(a, ...)
        local lol,foo,bar = ...

        if a == 1 then return 1 end
        if a == 2 then return {} end
        if a == 3 then return "", foo+2,3 end
    end

    local a,b,c = lol(3,1,2,3)

    types.assert(a, "")
    types.assert(b, 4)
    types.assert(c, 3)
]]
run[[
    function foo(a, b) return a+b end

    local a = foo(1,2)

    types.assert(a, 3)
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

    types.assert(ag, "hello")

]]
run[[
    local foo = {lol = 30}
    function foo:bar(a)
        return a+self.lol
    end

    types.assert(foo:bar(20), 50)

]]
run[[
    function prefix (w1, w2)
        return w1 .. ' ' .. w2
    end

    types.assert(prefix("hello", "world"), "hello world")
]]
run[[
    local func = function()
        local a = 1

        return function()
            return a
        end
    end

    local f = func()

    types.assert(f(), 1)
]]
run[[
    function prefix (w1, w2)
        return w1 .. ' ' .. w2
    end

    local w1,w2 = "foo", "bar"
    local statetab = {["foo bar"] = 1337}

    local test = statetab[prefix(w1, w2)]
    types.assert(test, 1337)
]]
run[[
    local function test(a)
        --if a > 10 then return a end
        return test(a+1)
    end

    types.assert(test(1), nil as any)
]]
run[[
    local function test(a): number
        if a > 10 then return a end
        return test(a+1)
    end

    types.assert(test(1), nil as number)
]]
run[[
    local a: string | number = 1

    local type test = function=(a: number, b: string)>(boolean, number)

    local foo,bar = test(1, "")

    types.assert(foo, nil as boolean)
    types.assert(bar, nil as number)
]]
run[[
    local type lol = number

    local type math = {
        sin = function=(a: lol, b: string)>(lol),
        cos = function=(a: string)>(lol),
        cos = function=(a: number)>(lol),
    }

    type math.lol = function=()>(lol)

    local a = math.sin(1, "")
    local b = math.lol() -- support overloads

    types.assert(a, nil as number)
    types.assert(b, nil as number)

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

    types.subset_of(b, _ as foo)
]]
run[[
  --  local a: (string|number)[] = {"", ""}
  --  a[1] = ""
  --  a[2] = 1
]]
run[[
    local type foo = {
        bar = function=(a: boolean, b: number)>(true) | function=(a: number)>(false),
    }

    local a = foo.bar(true, 1)
    local b = foo.bar(1)

    types.assert(a, nil as true)
    types.assert(b, nil as false)
]]
run[[
    local a: string = "1"
    local type a = string | number | (boolean | string)

    local type type_func = analyzer function(a: any,b: any,c: any) return types.String(), types.Number() end
    local a, b = type_func(a,2,3)
    types.assert(a, _ as string)
    types.assert(b, _ as number)
]]

--[[

    for i,v in ipairs({"LOL",2,3}) do
        if i == 1 then
            print(i,v)
            types.assert(i, _ as 1)
            types.assert(v, _ as "LOL")
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

    types.assert(a, _G.string)
]]
run[[
    local a = ""

    if a is string then
        types.assert(a, _ as "")
    end

]]
run[[
    local a = math.cos(_ as number)
    types.assert(a, nil as number)

    if a is number then
        types.assert(a, _ as number)
    end
]]
run[[
    local type math = {
        sin = function=(number)>(number)
    }

    local type old = math.cos
    type math.cos = function=(number)>(number)

    local a = math.sin(1)

    types.assert(a, _ as number)

    type math.cos = old
]]

run[[
    local type a = analyzer function()
        _G.LOL = true
    end

    local type b = analyzer function()
        _G.LOL = nil
        local t = analyzer:GetLocalOrEnvironmentValue(types.LString("a"), "typesystem")
        local func = t:GetData().lua_function
        func()
        if not _G.LOL then
            error("test fail")
        end
    end

    local a = b()
]]
run[[
    a: number = (lol as function=()>(number))()

    types.assert(a, nil as number)
]]
run[[
    local a = {}
    a.b: boolean, a.c: number = LOL as any, LOL2 as any
]]
run[[
    local type test = {
        sin = function=(number)>(number),
        cos = function=(number)>(number),
    }

    local a = test.sin(1)
]]
run[[
    local type lol = analyzer function(a: string) return a end
    local a: lol<|string|>
    types.assert(a, _ as string)
]]
run[[
    local a = {}
    function a:lol(a,b,c)
        return a+b+c
    end
    types.assert(a:lol(1,2,3), 6)
]]
run[[
    local a = {}
    function a.lol(_, a,b,c)
        return a+b+c
    end
    types.assert(a:lol(1,2,3), 6)
]]
run[[
    local a = {}
    function a.lol(a,b,c)
        return a+b+c
    end
    types.assert(a.lol(1,2,3), 6)
]]
run[[
    local a = {}
    function a.lol(...)
        local a,b,c = ...
        return a+b+c
    end
    types.assert(a.lol(1,2,3), 6)
]]
run[[
    local a = {}
    function a.lol(foo, ...)
        local a,b,c = ...
        return a+b+c+foo
    end
    types.assert(a.lol(10,1,2,3), 16)
]]
run[[
    local a = (function(...) return ...+... end)(10)
]]
run[[
    -- this will error with not defined
    --types.assert(TOTAL_STRANGER_COUNT, _ as number)
    --types.assert(TOTAL_STRANGER_STRING, _ as string)
]]
run[[
    local a = b as any
    local b = 2
    types.assert(a, _ as any)
]]
run[[
    local analyzer function identity(a: any)
        return a
    end
]]

pending[[
    for k,v in next, {1,2,3} do
        types.assert(_ as 1 | 2 | 3, _ as 1 | 2 | 3)
    end
]]
run[[
    local a = {a = self}
]]
run[[
    local a = setmetatable({} as {num = number}, meta)

    types.assert(a.num, _ as number)
]]
run[[

    local a,b,c = string.match("1 2 3", "(%d) (%d) (%d)")
    types.assert(a, nil as "1")
    types.assert(b, nil as "2")
    types.assert(c, nil as "3")

]]
run[[
    local def,{a,b,c} = {a=1,b=2,c=3}
    types.assert(a, 1)
    types.assert(b, 2)
    types.assert(c, 3)
    types.assert(def, def)
]]
run[[
    -- local a = nil
    -- local b = a and a.b or 1
 ]]
run[[
    local tbl = {} as {[true] = false}
    tbl[true] = false
    types.assert(tbl[true], false)
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
    types.assert(a, nil)
 ]]
run[[
    local tbl = {}
    local test = "asdawd"
  --  tbl[test] = tbl[test] or {} TODO
    tbl[test] = "1"
    types.assert(tbl[test], nil as "1")
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

    types.assert(tbl.a, nil as 1)
    types.assert(tbl.b, nil as 2)
    types.assert(a, nil as 1)
    types.assert(b, nil as 2)
]]
run[[
    local type a = 1
    types.assert(a, 1)
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

    local analyzer function check(func: any, other: any)
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

