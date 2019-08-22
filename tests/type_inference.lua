local test = require("tests.test")
local function check(tbl)
    for k,v in pairs(tbl) do
        tbl[k] = {code = v[1], expect = v[2], crawl = true, compare_tokens = true}
    end
    test.check_strings(tbl)
end

check {
    {
        "local a = 1",
        "local a: number(1) = 1"
    },
    {
        "local a: number = 1",
        "local a: number = 1"
    },
    {
        "local a: number | string = 1",
        "local a: number | string = 1"
    },
    {
        "function foo(a: number) end",
        "function foo(a: number) end"
    },
    {
        "function foo(a: number):string end",
        "function foo(a: number):string end",
    },
    {
        "function foo(a: number):string, number end",
        "function foo(a: number):string, number end",
    },
    {
        "type a = number; local num: a = 1",
        "local num: a = 1",
    },
}

local tests = {[[
    local a = 1
    type_assert(a, 1)
]],[[
    local a
    a = 1
    type_assert(a, 1)
]],[[
    local a = {}
    a.foo = {}

    local c = 0

    function a:bar()
        type_assert(self, a)
        c = 1
    end

    a:bar()

    type_assert(c, 1)
]], [[
    local function test()

    end

    type_assert(test, nil as function():)
]], [[
    local a = 1
    repeat
        type_assert(a, 1)
    until false
]], [[
    local c = 0
    for i = 1, 10, 2 do
        type_assert(i, nil as number)
        if i == 1 then
            c = 1
            break
        end
    end
    type_assert(c, 1)
]], [[
    local a = 0
    while false do
        a = 1
    end
    type_assert(a, 0)
]], [[
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
]], [[
    local a = 1+2+3+4
    local b = nil

    local function print(foo)
        return foo
    end

    if a then
        b = print(a+10)
    end

    type_assert(b, 20)
    type_assert(a, 10)
]], [[
    local a
    a = 2

    if true then
        local function foo(lol)
            return foo(lol), nil
        end
        local complex = foo(a)
        type_assert(foo, nil as function(_:any, _:nil):number )
    end
]], [[
    b = {}
    b.lol = 1

    local a = b

    local function foo(tbl)
        return tbl.lol + 1
    end

    local c = foo(a)

    type_assert(c, 2)
]], [[
    local META = {}
    META.__index = META

    function META:Test(a,b,c)
        return 1+c,2+b,3+a
    end

    local a,b,c = META:Test(1,2,3)

    local ret

    if someunknownglobal then
        ret = a+b+c
    end

    type_assert(ret, 12)
]], [[
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
]], [[
    local a = 1337
    for i = 1, 10 do
        type_assert(i, 1)
        if i == 15 then
            a = 7777
            break
        end
    end
    type_assert(a, 1337)
]], [[
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
]], [[
    function foo(a, b) return a+b end

    local a = foo(1,2)

    type_assert(a, 3)
]],[[
local   a,b,c = 1,2,3
        d,e,f = 4,5,6

type_assert(a, 1)
type_assert(b, 2)
type_assert(c, 3)

type_assert(d, 4)
type_assert(e, 5)
type_assert(f, 6)

local   vararg_1 = ...
        vararg_2 = ...

type_assert(vararg_1, any)
type_assert(vararg_2, any)

local function test(...)
    return a,b,c, ...
end

A, B, C, D = test(), 4

type_assert(A, 1)
type_assert(B, 2)
type_assert(C, 3)
type_assert(D, nil as ...) -- THIS IS WRONG, tuple of any?

local z,x,y,æ,ø,å = test(4,5,6)
local novalue

type_assert(z, 1)
type_assert(x, 2)
type_assert(y, 3)
type_assert(æ, 4)
type_assert(ø, 5)
type_assert(å, 6)

]], [[
local a = {b = {c = {}}}
a.b.c = 1
]],[[
    local a = function(b)
        if b then
            return true
        end
        return 1,2,3
    end

    a()
    a(true)

]],[[
    function string(ok)
        if ok then
            return 2
        else
            return "hello"
        end
    end

    string(true)
    local ag = string()

    type_assert(ag, 2)

]],[[
    local foo = {lol = 3}
    function foo:bar(a)
        return a+self.lol
    end

    type_assert(foo:bar(2), 5)

]],[[
    function prefix (w1, w2)
        return w1 .. ' ' .. w2
    end

    type_assert(prefix("hello", "world"), "hello world")
]],[[
    local function test(max)
        for i = 1, max do
            if i == 20 then
                return false
            end

            if i == 5 then
                return true
            end
        end
        return "lol"
    end

    local a = test(20)
    local b = test(5)
    local c = test(1)

    local LOL = a

    type_assert(a, false)
    type_assert(b, true)
    type_assert(c, "lol")
]], [[
    local func = function()
        local a = 1

        return function()
            return a
        end
    end

    local f = func()

    type_assert(f(), 1)
]],[[
    function prefix (w1, w2)
        return w1 .. ' ' .. w2
    end

    local w1,w2 = "foo", "bar"
    local statetab = {["foo bar"] = 1337}

    local test = statetab[prefix(w1, w2)]
    type_assert(test, 1337)
]],[[
    local function test(a)
        --if a > 10 then return a end
        return test(a+1)
    end

    type_assert(test(1), nil as any)
]],[[
    local function test(a)
        if a > 10 then return a end
        return test(a+1)
    end

    type_assert(test(1), nil as number)
]],[[
    local a: string | number = 1

    local function test(a: number, b: string): boolean, number

    end

    local foo,bar = test(1, "")

    type_assert(foo, nil as boolean)
    type_assert(bar, nil as number)
]],[[
    do
        type x = boolean | number
    end

    type c = x
    local a: x
    type b = {foo = a}
    local c: function(a: number, b:number): b, b

    type_assert(c, nil as function(_:table, _:table): number, number)

]], [[
    local function test(a:number,b: number)
        return a + b
    end

    type_assert(test, nil as function(_:number, _:number): number)
]],[[
    type lol = number

    interface math {
        sin = function(a: lol, b: string): lol
        cos = function(a: string): lol
        cos = function(a: number): lol
    }

    interface math {
        lol = function(): lol
    }


    local a = math.sin(1, "")
    local b = math.lol()

    type_assert(a, nil as number)
    type_assert(b, nil as number)
]], [[
    interface foo {
        a = number
        b = {
            str = string,
        }
    }

    local b: foo = {}
    local c = b.a
    local d = b.b.str

    type_assert(b, nil as foo)
]], [[
  --  local a: (string|number)[] = {"", ""}
  --  a[1] = ""
  --  a[2] = 1
]], [[
    interface foo {
        bar = function(a: boolean, b: number): true
        bar = function(a: number): false
    }

    local a = foo.bar(true, 1)
    local b = foo.bar(1)

    type_assert(a, true)
    type_assert(b, false)
]],[[
    local a: string = "1"
    type a = string | number | (boolean | string)

    type type_func = function(a,b,c) return types.Type("string"), types.Type("number") end
    local a, b = type_func(a,2,3)
    type_assert(a, _ as string)
    type_assert(b, _ as number)
]],[[
    type Array = function(T, L)
        return types.Type("list", T.name, L.value)
    end

    type Exclude = function(T, U)
        if T.types then
            for i,v in ipairs(T.types) do
                if v:IsType(U) and v.value == U.value then
                    table.remove(T.types, i)
                end
            end
        end
        return T
    end

    local list: Array<number, 3> = {1, 2, 3}
    local a: Exclude<1|2|3, 2> = 1

    type_assert(a, _ as 1|3)
    type_assert(a, _ as number[3])
]],[[
    type next = function(t, k)
        -- behavior of the external next function
        -- we can literally just pass what the next function returns
        local a,b

        if k then
            a,b = next(t.value, k.value)
        else
            a,b = next(t.value)
        end

        if type(a) == "table" and a.name then
            a = a.value
        end

        if type(b) == "table" and b.name then
            b = b.value
        end

        return types.Type(type(a), a), types.Type(type(b), b)
    end

    function pairs(t)
        return next, t, nil
    end

    do
        local function iter(a, i)
            i = i + 1
            local v = a[i]
            if v then
                return i, v
            end
        end

        function ipairs(a)
            return iter, a, 0
        end
    end

    for k,v in pairs({foo = true}) do
        type_assert(k, _ as "foo")
        type_assert(v, _ as true)
    end

    for i,v in ipairs({"LOL",2,3}) do
        type_assert(i, _ as 1)
        type_assert(v, _ as "LOL")
    end
]],[[
    type next = function(tbl, _key)
        local key, val

        for k, v in pairs(tbl.value) do
            if not key then
                key = types.Type(type(k))
            elseif not key:IsType(k) then
                if type(k) == "string" then
                    key = types.Fuse(key, types.Type("string"))
                else
                    key = types.Fuse(key, types.Type(k.name))
                end
            end

            if not val then
                val = types.Type(type(v))
            else
                if not val:IsType(v) then
                    val = types.Fuse(val, types.Type(v.name))
                end
            end
        end
    end

    local a = {
        foo = true,
        bar = false,
        a = 1,
        lol = {},
    }

    local k, v = next(a)
]],[[
    local a: _G.string

    type_assert(a, _G.string)
]],[[
    local a = ""

    if a is string then
        type_assert(a, _ as string)
    end

]],[[
    local a = math.cos(1)
    type_assert(a, nil as number)

    if a is number then
        type_assert(a, _ as number)
    end
]],[[
    interface math {
        sin = function(number): number
    }

    interface math {
        cos = function(number): number
    }

    local a = math.sin(1)

    type_assert(a, _ as number)
]],[=[
    local a = 1
    function b(lol)
        if lol == 1 then return "foo" end
        return lol + 4, true
    end
    local d = b(2)
    local d = b(a)

    local lol: {a = boolean} = {}
    lol.a = true

    function lol:Foo(foo, bar)
        local a = self.a
    end

    --local lol: string[] = {}

    --local a = table.concat(lol)
]=],[[
    type a = function()
        _G.LOL = true
    end

    type b = function()
        _G.LOL = nil
        crawler:GetValue("a", "typesystem").func()
        if not _G.LOL then
            error("test fail")
        end
    end

    local a = b()
]],[[
    a: number = lol()

    type_assert(a, _ as number)
]], [[
    local a = {}
    a.b: boolean, a.c: number = LOL, LOL2
]],[[
    type test = {
        sin = (function(number): number),
        cos = (function(number): number),
    }

    local a = test.sin(1)
]],[[
    type lol = function(a) return a end
    local a: lol<string>
    type_expect(a, _ as string)
]],[[
    local a = {}
    function a:lol(a,b,c)
        return a+b+c
    end
    type_assert(a:lol(1,2,3), 6)
]],[[
    local a = {}
    function a.lol(_, a,b,c)
        return a+b+c
    end
    type_assert(a:lol(1,2,3), 6)
]],[[
    local a = {}
    function a.lol(a,b,c)
        return a+b+c
    end
    type_assert(a.lol(1,2,3), 6)
]],[[
    local a = {}
    function a.lol(...)
        local a,b,c = ...
        return a+b+c
    end
    type_assert(a.lol(1,2,3), 6)
]],[[
    local a = {}
    function a.lol(foo, ...)
        local a,b,c = ...
        return a+b+c+foo
    end
    type_assert(a.lol(10,1,2,3), 16)
]],[[
    local a = (function(...) return ...+... end)(10)
]],[[
    local k,v = next({k = 1})
]],[[
    type_assert(TOTAL_STRANGER_COUNT, _ as number)
    type_assert(TOTAL_STRANGER_STRING, _ as string)
]]}



local base_lib = io.open("oh/base_lib.oh"):read("*all")
local Crawler = require("oh.crawler")
local LuaEmitter = require("oh.lua_emitter")

for _, code in ipairs(tests) do
    if code == false then return end

    local code = base_lib .. "\n" .. code

    --local path = "oh/parser.lua"

    local em = LuaEmitter()

    local oh = require("oh")

    local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code, "test " .. _)), "test " .. _, code))

    local crawler = Crawler()

    --crawler.OnEvent = crawler.DumpEvent

    crawler.code = code
    crawler.name = "test"
    crawler:CrawlStatement(ast)
end