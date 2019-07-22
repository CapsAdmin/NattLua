local tests = {[[
    local a = 1
    assert_type(a, "number", 1)
]],[[
    local a
    a = 1
    assert_type(a, "number", 1)
]],[[
    local a = {}
    a.foo = {}

    local c = 0

    function a:bar()
        assert_type(self, "table")
        c = 1
    end

    a:bar()

    assert_type(c, "number", 1)
]], [[
    local function test()

    end

    assert_type(test, "function")
]], [[
    local a = 1
    repeat
        assert_type(a, "number")
    until false
]], [[
    local c = 0
    for i = 1, 10, 2 do
        assert_type(i, "number")
        if i == 1 then
            c = 1
            break
        end
    end
    assert_type(c, "number", 1)
]], [[
    local a = {foo = true, bar = false, faz = 1}
    for k,v in pairs(a) do
        assert_type(k, "string")
        assert_type(v, {"number", "string"})
    end
]], [[
    local a = 0
    while false do
        a = 1
    end

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

    assert_type(a, "number", 6)
]], [[
    local a = 1+2+3+4
    local b = nil

    local function print(foo)
        return foo
    end

    if a then
        b = print(a+10)
    end

    assert_type(b, "number", 20)

]], [[
    local a
    a = 2

    if true then
        local function foo(lol)
            return foo(lol), nil
        end
        local complex = foo(a)
        assert_type(foo, "function", {{"any"}, {"nil"}}, {{"number"}} )
    end
]], [[
    b = {}
    b.lol = 1

    local a = b

    local function foo(tbl)
        return tbl.lol + 1
    end

    local c = foo(a)

    assert_type(c, "number", 2)
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

    assert_type(ret, "number", 12)
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

        assert_type(a, "number", 2)
    end
]], [[
    local a = 1337
    for i = 1, 10 do
        assert_type(i, "number", 1, 10)
        if i == 15 then
            a = 7777
            break
        end
    end
    assert_type(a, "number", 1337)
]], [[
    local function lol(a, ...)
        local lol,foo,bar = ...

        if a == 1 then return 1 end
        if a == 2 then return {} end
        if a == 3 then return "", foo+2,3 end
    end

    local a,b,c = lol(3,1,2,3)

    assert_type(a, "string", "")
    assert_type(b, "number", 4)
    assert_type(c, "number", 3)
]], [[
    function foo(a, b) return a+b end

    local a = foo(1,2)

    assert_type(a, "number", 3)
]], [[
    local a = 1
    assert_type(a, "number")
]], [[
local   a,b,c = 1,2,3
        d,e,f = 4,5,6

assert_type(a, "number", 1)
assert_type(b, "number", 2)
assert_type(c, "number", 3)

assert_type(d, "number", 4)
assert_type(e, "number", 5)
assert_type(f, "number", 6)

local   vararg_1 = ...
        vararg_2 = ...

assert_type(vararg_1, "nil")
assert_type(vararg_2, "nil")

local function test(...)
    return a,b,c, ...
end

A, B, C, D = test(), 4

assert_type(A, "number", 1)
assert_type(B, "number", 2)
assert_type(C, "number", 3)
assert_type(D, "...") -- THIS IS WRONG, tuple of any?

local z,x,y,æ,ø,å = test(4,5,6)
local novalue

assert_type(z, "number", 1)
assert_type(x, "number", 2)
assert_type(y, "number", 3)
assert_type(æ, "number", 4)
assert_type(ø, "number", 5)
assert_type(å, "number", 6)

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

    assert_type(ag, "number", 2)

]],[[
    local foo = {lol = 3}
    function foo:bar(a)
        return a+self.lol
    end

    assert_type(foo:bar(2), "number", 5)

]],[[
    function prefix (w1, w2)
        return w1 .. ' ' .. w2
    end

    assert_type(prefix("hello", "world"), "string", "hello world")
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

    assert_type(a, "boolean", false)
    assert_type(b, "boolean", true)
    assert_type(c, "string", "lol")
]], [[
    local func = function()
        local a = 1

        return function()
            return a
        end
    end

    local f = func()

    assert_type(f(), "number", 1)
]],[[
    local function pairs(t)
        local k, v
        return function(v, k)
            local k, v = next(t, k)

            return k,v
        end
    end

    for k,v in pairs({foo=1, bar=2, faz=3}) do
        assert_type(k, "string")
        assert_type(v, "number")
    end
]],[[
    local t = {foo=1, bar=2, faz="str"}
    pairs(t)
    for k,v in pairs(t) do
        assert_type(k, "string")
        assert_type(v, {"string", "number"})
    end
]],[[
    function prefix (w1, w2)
        return w1 .. ' ' .. w2
    end

    local w1,w2 = "foo", "bar"
    local statetab = {["foo bar"] = 1337}

    local test = statetab[prefix(w1, w2)]
    assert_type(test, "number", 1337)
]],[[
    local function test(a)
        --if a > 10 then return a end
        return test(a+1)
    end

    assert_type(test(1), "any")
]],[[
    local function test(a)
        if a > 10 then return a end
        return test(a+1)
    end

    assert_type(test(1), "number")
]],[[
    local a: string | number = 1

    local function test(a: number, b: string): boolean, number

    end

    local foo,bar = test(1, "")

    assert_type(foo, "boolean")
    assert_type(bar, "number")
]],[[
    do
        type x = boolean | number
    end

    type c = type x
    local a: type x
    type b = {foo: type a}
    local c: (a: number, b:number) => b, b

    assert_type(c, "function", {{"table"}, {"table"}}, {{"number"}, {"number"}} )

]], [[
    local function test(a:number,b: number)
        return a+b
    end

    assert_type(test, "function", {{"number"}}, {{"number"}, {"number"}} )
]]}

tests = {[[
    type math = {}
    type math.sin = (a: number): number
    type math.cos = (a: number): number

    local math: math


    local a = math.sin(1)
    --print(a)
]]}

local Crawler = require("oh.crawler")
local Lexer = require("oh.lexer")
local Parser = require("oh.parser")
local LuaEmitter = require("oh.lua_emitter")
local types = require("oh.types")

for _, code in ipairs(tests) do
    if code == false then return end

    --local path = "oh/parser.lua"
    --local code = assert(io.open(path)):read("*all")

    local tk = Lexer(code)
    local ps = Parser()
    local em = LuaEmitter()

    local oh = require("oh")
    ps.OnError = oh.DefaultErrorHandler
    tk.OnError = oh.DefaultErrorHandler

    local tokens = assert(tk:GetTokens())
    local ast = assert(ps:BuildAST(tokens))

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

if false then

    crawler:DeclareGlobal("assert_type", types.Type("function", {types.Type"any"}, {types.Type"..."}, function(what, type, value, ...)
        if type:IsType("table") then
            type = table_to_types(type)
        end

        if not what:IsType(type.value) then
            print(code)
            error("expected " .. type.value .. " got " .. tostring(what))
        end

        if type.value == "function" then
            local expected_ret, expected_args = value, ...
            local func = what

            if expected_ret then
                for i, ret_slot in ipairs(expected_ret.value) do
                    ret_slot = table_to_types(ret_slot)
                    if not ret_slot:IsType(func.ret[i]) then
                        error("expected return type " .. tostring(ret_slot) .. " to #" .. i .. " got " .. tostring(func.ret[i] == nil and "nothing" or func.ret[i]))
                    end
                end
            end

            if expected_args then
                for i, arg in ipairs(expected_args.value) do
                    arg = table_to_types(arg)
                    if not arg:IsType(func.arguments[i]) then
                        error("expected argument type " .. tostring(arg) .. " to #" .. i .. " got " .. tostring(func.arguments[i]))
                    end
                end
            end
        else
            if value ~= nil and value.value ~= what.value then
                error("expected " .. tostring(value.value) .. " got " .. tostring(what.value))
            end

            local max = ...
            if max and type.value == "number" then
                if not what.max or not what.max.value or max.value ~= what.max.value then
                    error("expected max " .. tostring(max.value) .. " got " .. tostring(what.max.value))
                end
            end
        end

        return types.Type("boolean", true)
    end))

    crawler:DeclareGlobal("next", types.Type("function", {types.Type"any", types.Type"any"}, {types.Type"any", types.Type"any"}, function(tbl, key)
        local key, val = next(tbl.value)

        return types.Type("string", key), val
    end))

    crawler:DeclareGlobal("pairs", types.Type("function", {types.Type"table"}, {types.Type"table"}, function(tbl)
        local key, val
        return function()
            for k,v in pairs(tbl.value) do
                if type(k) == "string" then
                    k = types.Type("string", k)
                end

                if not key then
                    key = k
                else
                    key = key + k
                end

                if not val then
                    val = v
                else
                    val = val + v
                end
            end

            return {key, val}
        end, tbl
    end))

    add("io", {lines = types.Type("function", {types.Type"string"}, {types.Type"number" + types.Type"nil" + types.Type"string"})})
    add("table", {
        insert = types.Type("function", {types.Type"nil"}, {types.Type"table"}),
        getn = types.Type("function", {types.Type"number"}, {types.Type"table"}),
        })
    add("math", {
        random = types.Type("function", {types.Type"number"}, {types.Type"number"}),
        floor = types.Type("function", {types.Type"number"}, {types.Type"number"}),
        ceil = types.Type("function", {types.Type"number"}, {types.Type"number"}),

    })
    add("string", {
        find = types.Type("function", {types.Type"number" + types.Type"nil", types.Type"number" + types.Type"nil", types.Type"string" + types.Type"nil"}, {types.Type"string", types.Type"string"}),
        sub = types.Type("function", {types.Type"string"}, {types.Type"number", types.Type"number" + types.Type"nil"}),
    })

end

    crawler.code = code
    crawler.name = "test"
    crawler:CrawlStatement(ast)
end