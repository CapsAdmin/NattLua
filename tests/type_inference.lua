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
    local a = {foo = true, bar = false, faz = 1}
    for k,v in pairs(a) do
        type_assert(k, "")
        type_assert(v, nil as number | string)
    end
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

type_assert(vararg_1, nil)
type_assert(vararg_2, nil)

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
    local function pairs(t)
        local k, v
        return function(v, k)
            local k, v = next(t, k)

            return k,v
        end
    end

    for k,v in pairs({foo=1, bar=2, faz=3}) do
        type_assert(k, "")
        type_assert(v, nil as number)
    end
]],[[
    local t = {foo=1, bar=2, faz="str"}
    pairs(t)
    for k,v in pairs(t) do
        type_assert(k, "")
        type_assert(v, "" | number)
    end
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
    local a: (string|number)[] = {"", ""}
    a[1] = ""
    a[2] = 1
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
    local a: string = 1
    type a = string | number | (boolean | string)

    type type_func = function(a,b,c) return types.Type("string"), types.Type("number") end
    local a, b = type_func(a,2,3)
    type_assert(a, "")
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

    type_assert(a, _ as 3|1)
    type_assert(a, _ as number[3])
]]}

tests = {[[
    type next = function(t, k)
        return next(t.value, k.value)
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

    for k,v in ipairs({1,2,3}) do
        print(k,v)
    end
]]}

local base_lib = io.open("oh/base_lib.oh"):read("*all")


local Crawler = require("oh.crawler")

local LuaEmitter = require("oh.lua_emitter")
local types = require("oh.types")

for _, code in ipairs(tests) do
    if code == false then return end

    --local code = base_lib .. code

    --local path = "oh/parser.lua"

    local em = LuaEmitter()

    local oh = require("oh")

    local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code, "test " .. _)), "test " .. _, code))

    local crawler = Crawler()

    crawler.OnEvent = crawler.DumpEvent

    local function add(lib, t)
        local tbl = types.Type("table")
        tbl.value = t
        crawler:DeclareGlobal(lib, tbl)
    end

    local function table_to_types(type)
        local combined = types.Type(type.value[1].value)
        for i = 2, #type.value do
            combined = combined + types.Type(type.value[i].value)
        end
        return combined
    end

    crawler:SetGlobal("next", types.Type("function", {types.Type"any", types.Type"any"}, {types.Type"any", types.Type"any"}, function(tbl, key)
        local key, val = next(tbl.value)

        return types.Type("string", key), val
    end), "typesystem")

    crawler.code = code
    crawler.name = "test"
    crawler:CrawlStatement(ast)
end