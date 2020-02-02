local oh = require("oh")
local C = oh.Code

local function R(code_data, expect_error)
    local ok, err = code_data:Analyze()

    if expect_error then
        if not err then
            error("expected error, got\n\n\n[" .. tostring(ok) .. ", " .. tostring(err) .. "]")
        elseif type(expect_error) == "string" and not err:find(expect_error) then
            error("expected error " .. expect_error .. " got\n\n\n" .. err)
        end
    else
        if not ok then
            local ok, err2 = C(code_data.code):Analyze(true)
            print(code_data.code)
            error(err)
        end
    end
end

R(C[[
    type a = 1 or 2

    type_assert(1 or 2, 1)
    type_assert(-1, -1)
    type_assert(#{1,2,3}, 3)

    type_assert(1-2, -1)
    type_assert(1+2, 3)
    type_assert(2*3, 6)
    type_assert(1/2, 0.5)
    type_assert(2^3, 8)
    type_assert("a" .. "b", "ab")

    type_assert(1>2, false)
    type_assert(1%1, 0)

    local a = nil
    local b = 1
    type_assert(b or a, 1)

    local b = {}
    local a = 1
    type_assert(b or a, b)
]])

R(C[[
    do --- tnew
        local a = nil
        local b = {}
        local t = {[true] = a, [false] = b or 1}
        assert(t[true] == nil)
        assert(t[false] == b)
    end

    do --- tdup
        local b = {}
        local t = {[true] = nil, [false] = b or 1}
        assert(t[true] == nil)
        assert(t[false] == b)
    end
]])

R(C[[
    local a = 1
    type_assert(a, nil as 1)
]])

R(C[[
    local a = {a = 1}
    type_assert(a.a, nil as 1)
]])

R(C[[
    local a = {a = {a = 1}}
    type_assert(a.a.a, nil as 1)
]])

R(C[[
    local a = {a = 1}
    a.a = nil
    type_assert(a.a, nil)
]])

R(C[[
    local a = {}
    a.a = 1
    type_assert(a.a, nil as number)
]])

R(C[[
    local a = ""
    type_assert(a, nil as string)
]])
R(C[[
    local type a = number
    type_assert(a, _ as number)
]])
R(C[[
    local a
    a = 1
    type_assert(a, 1)
]])
R(C[[
    local a = {}
    a.foo = {}

    local c = 0

    function a:bar()
        type_assert(self, a)
        c = 1
    end

    a:bar()

    type_assert(c, 1)
]])
R(C[[
    local function test()

    end

    type_assert(test, nil as function():)
]])
R(C[[
    local a = 1
    repeat
        type_assert(a, 1)
    until false
]])
R(C[[
    local c = 0
    for i = 1, 10, 2 do
        type_assert(i, nil as number)
        if i == 1 then
            c = 1
            break
        end
    end
    type_assert(c, 1)
]])
R(C[[
    local a = 0
    while false do
        a = 1
    end
    type_assert(a, 0)
]])
R(C[[
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
]])
R(C[[
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
]])
R(C[[
    local a
    a = 2

    if true then
        local function foo(lol)
            return foo(lol), nil
        end
        local complex = foo(a)
        type_assert(foo, nil as function(_:any, _:nil):number )
    end
]])
R(C[[
    b = {}
    b.lol = 1

    local a = b

    local function foo(tbal)
        return tbal.lol + 1
    end

    local c = foo(a)

    type_assert(c, 2)
]])
R(C[[
    local META = {}
    META.__index = META

    function META:Test(a,b,c)
        return 1+c,2+b,3+a
    end

    local a,b,c = META:Test(1,2,3)

    local ret

    if someunknownglobal as any then
        ret = a+b+c
    end

    type_assert(ret, 12)
]])
R(C[[
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
]])
R(C[[
    local a = 1337
    for i = 1, 10 do
        type_assert(i, 1)
        if i == 15 then
            a = 7777
            break
        end
    end
    type_assert(a, 1337)
]])
R(C[[
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
]])
R(C[[
    function foo(a, b) return a+b end

    local a = foo(1,2)

    type_assert(a, 3)
]])
R(C[[
local   a,b,c = 1,2,3
        d,e,f = 4,5,6

type_assert(a, 1)
type_assert(b, 2)
type_assert(c, 3)

type_assert(d, 4)
type_assert(e, 5)
type_assert(f, 6)

local   vararg_1 = ... as any
        vararg_2 = ... as any

type_assert(vararg_1, _ as any)
type_assert(vararg_2, _ as any)

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

]])
R(C[[
local a = {b = {c = {}}}
a.b.c = 1
]])
R(C[[
    local a = function(b)
        if b then
            return true
        end
        return 1,2,3
    end

    a()
    a(true)

]])
R(C[[
    function string(ok: boolean)
        if ok then
            return 2
        else
            return "hello"
        end
    end

    string(true)
    local ag = string(false)

    type_assert(ag, "hello")

]])
R(C[[
    local foo = {lol = 30}
    function foo:bar(a)
        return a+self.lol
    end

    type_assert(foo:bar(20), 50)

]])
R(C[[
    function prefix (w1, w2)
        return w1 .. ' ' .. w2
    end

    type_assert(prefix("hello", "world"), "hello world")
]])
R(C[[
    local function test(max: number)
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
]])
R(C[[
    local func = function()
        local a = 1

        return function()
            return a
        end
    end

    local f = func()

    type_assert(f(), 1)
]])
R(C[[
    function prefix (w1, w2)
        return w1 .. ' ' .. w2
    end

    local w1,w2 = "foo", "bar"
    local statetab = {["foo bar"] = 1337}

    local test = statetab[prefix(w1, w2)]
    type_assert(test, 1337)
]])
R(C[[
    local function test(a)
        --if a > 10 then return a end
        return test(a+1)
    end

    type_assert(test(1), nil as any)
]])
R(C[[
    local function test(a): number
        if a > 10 then return a end
        return test(a+1)
    end

    type_assert(test(1), nil as number)
]])
R(C[[
    local a: string | number = 1

    local type test = function(a: number, b: string): boolean, number

    local foo,bar = test(1, "")

    type_assert(foo, nil as boolean)
    type_assert(bar, nil as number)
]])
R(C[[
    do
        type x = boolean | number
    end

    type c = x
    local a: c
    type b = {foo = a as any}
    local c: function(a: number, b:number): b, b

    type_assert(c, nil as function(_:table, _:table): number, number)

]])
R(C[[
    local function test(a:number,b: number)
        return a + b
    end

    type_assert(test, nil as function(_:number, _:number): number)
]])
R(C[[
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
    local b = math.lol() -- support overloads

    type_assert(a, nil as number)
    type_assert(b, nil as number)
]])
R(C[[
    interface foo {
        a = number
        b = {
            str = string,
        }
    }

    local b: foo = {a=1, b={str="lol"}}
    local c = b.a
    local d = b.b.str

    type_assert(b, nil as foo)
]])
R(C[[
  --  local a: (string|number)[] = {"", ""}
  --  a[1] = ""
  --  a[2] = 1
]])
R(C[[
    interface foo {
        bar = function(a: boolean, b: number): true
        bar = function(a: number): false
    }

    local a = foo.bar(true, 1)
    local b = foo.bar(1)

    type_assert(a, true)
    type_assert(b, false)
]])
R(C[[
    local a: string = "1"
    type a = string | number | (boolean | string)

    type type_func = function(a,b,c) return types.Create("string"), types.Create("number") end
    local a, b = type_func(a,2,3)
    type_assert(a, _ as string)
    type_assert(b, _ as number)
]])
R(C[[
    type Array = function(T, L)
        return types.Create("list", {values = T.name, length = L.data})
    end

    type Exclude = function(T, U)
        T:RemoveElement(U)
        return T
    end

    local a: Exclude<1|2|3, 2> = 1
    type_assert(a, _ as 1|3)

    local list: Array<number, 3> = {1, 2, 3}
    type_assert(list, _ as number[3])
]])
R(C[[
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
]])
R(C[[
    type next = function(tbl, _key)
        local key, val

        -- old typesystem
        if tbl.value then

            for k, v in pairs(tbl.value) do
                if not key then
                    key = types.Create(type(k))
                elseif not key:IsType(k) then
                    if type(k) == "string" then
                        key = types.Fuse(key, types.Create("string"))
                    else
                        key = types.Fuse(key, types.Create(k.name))
                    end
                end

                if not val then
                    val = types.Create(type(v))
                else
                    if not val:IsType(v) then
                        val = types.Fuse(val, types.Create(v.name))
                    end
                end
            end
        end

        -- new typesystem
        if tbl.data then
            key, val = types.Set:new(), types.Set:new()
            if tbl.Type == "dictionary" then
                for _, keyval in ipairs(tbl.data) do
                    key:AddElement(keyval.key)
                    val:AddElement(keyval.val)
                end
            elseif tbl.Type == "tuple" then
                key = types.Create("number", i, const)
                key.max = tbl.max and tbl.max:Copy() or nil
                for _, val in ipairs(tbl.data) do
                    val:AddElement(val)
                end
            end
        end

        return key, val
    end

    local a = {
        foo = true,
        bar = false,
        a = 1,
        lol = {},
    }

    local k, v = next(a)
]])
R(C[[
    local a: _G.string

    type_assert(a, _G.string)
]])
R(C[[
    local a = ""

    if a is string then
        type_assert(a, _ as string)
    end

]])
R(C[[
    local a = math.cos(1)
    type_assert(a, nil as number)

    if a is number then
        type_assert(a, _ as number)
    end
]])
R(C[[
    interface math {
        sin = function(number): number
    }

    interface math {
        cos = function(number): number
    }

    local a = math.sin(1)

    type_assert(a, _ as number)
]])

R(C[=[
    local a = 1
    function b(lol: number)
        if lol == 1 then return "foo" end
        return lol + 4, true
    end
    local d = b(2)
    local d = b(a)

    local lol: {a = boolean, Foo = function():} = {}
    lol.a = true

    function lol:Foo(foo, bar)
        local a = self.a
    end

    --local lol: string[] = {}

    --local a = table.concat(lol)
]=])

R(C[[
    type a = function()
        _G.LOL = true
    end

    type b = function()
        _G.LOL = nil
        local t = analyzer:GetValue("a", "typesystem")
        local func = t.data.lua_function
        func()
        if not _G.LOL then
            error("test fail")
        end
    end

    local a = b()
]])
R(C[[
    a: number = (lol as function(): number)()

    type_assert(a, nil as number)
]])
R(C[[
    local a = {}
    a.b: boolean, a.c: number = LOL as any, LOL2 as any
]])
R(C[[
    type test = {
        sin = (function(number): number),
        cos = (function(number): number),
    }

    local a = test.sin(1)
]])
R(C[[
    type lol = function(a) return a end
    local a: lol<string>
    type_assert(a, _ as string)
]])
R(C[[
    local a = {}
    function a:lol(a,b,c)
        return a+b+c
    end
    type_assert(a:lol(1,2,3), 6)
]])
R(C[[
    local a = {}
    function a.lol(_, a,b,c)
        return a+b+c
    end
    type_assert(a:lol(1,2,3), 6)
]])
R(C[[
    local a = {}
    function a.lol(a,b,c)
        return a+b+c
    end
    type_assert(a.lol(1,2,3), 6)
]])
R(C[[
    local a = {}
    function a.lol(...)
        local a,b,c = ...
        return a+b+c
    end
    type_assert(a.lol(1,2,3), 6)
]])
R(C[[
    local a = {}
    function a.lol(foo, ...)
        local a,b,c = ...
        return a+b+c+foo
    end
    type_assert(a.lol(10,1,2,3), 16)
]])
R(C[[
    local a = (function(...) return ...+... end)(10)
]])
R(C[[
    local k,v = next({k = 1})
    type_assert(k, nil as "k")
    type_assert(v, nil as 1)
]])
R(C[[
    -- this will error with not defined
    --type_assert(TOTAL_STRANGER_COUNT, _ as number)
    --type_assert(TOTAL_STRANGER_STRING, _ as string)
]])
R(C[[
    local a = b as any
    local b = 2
    type_assert(a, _ as any)
]])
R(C[[
    type test = (function(boolean, boolean): number) | (function(boolean): string)

    local a = test(true, true)
    local b = test(true)

    type_assert(a, _ as number)
    type_assert(b, _ as string)
]])
R(C[[
    local type function identity(a)
        return a
    end
]])
R(C[[
    local a = 1
    while true do
        a = a + 1
    end
    local b = a

    repeat
        b = b + 1
    until true

    local c = b
]])
R(C[[
    for k,v in next, {1,2,3} do
        print(k,v)
    end
]])
R(C[[
    local a = {a = self}
]])
R(C[[
    local a = setmetatable({} as {num = number}, meta)

    type_assert(a.num, _ as number)
]])
R(C[[
    local meta: {num = number, __index = self} = {}
    meta.__index = meta

    local a = setmetatable({}, meta)

    type_assert(a.num, _ as number) -- implement meta tables
]])
R(C[[
    local type Vec2 = {x = number, y = number}
    local type Vec3 = {z = number} extends Vec2

    local type Base = {
        Test = function(self): number,
    }

    local type Foo = Base extends {
        SetPos = (function(self, pos: Vec3): nil),
        GetPos = (function(self): Vec3),
    }

    local x: Foo = {}
    x:SetPos({x = 1, y = 2, z = 3})
    local a = x:GetPos()
    local z = a.x + 1

    type_assert(z, _ as number)

    local test = x:Test()
    type_assert(test, _ as number)
]])
R(C[[
    local function lol()
        return "hello", 1337
    end

    local a = lol():gsub("", "")

    type_assert(a, _ as string)
]])
R(C[[

    local a,b,c = string.match("1 2 3", "(%d) (%d) (%d)")
    type_assert(a, nil as string)
    type_assert(b, nil as string)
    type_assert(c, nil as string)

]])
R(C[[
    -- val should be a string and lol should be any
    string.gsub("foo bar", "(%s)", function(val, lol)
        type_assert(val, _ as string)
        type_assert(lol, _ as any)
    end)
]])
R(C[[
    local _: boolean
    local a = 0

    -- boolean which has no known value should be truthy
    if _ then
        a = 1
    end
    type_assert(a, 1)
]])
R(C[[
    -- 1..any
    for i = 1, _ do

    end
]])
R(C[[
    local a, b = 0, 0
    for i = 1, 10 do
        if 5 == i then
            a = 1
        end
        if i == 5 then
            b = 1
        end
    end
    type_assert(a, 1)
    type_assert(b, 1)
]])
R(C[[
    local def,{a,b,c} = {a=1,b=2,c=3}
    type_assert(a, 1)
    type_assert(b, 2)
    type_assert(c, 3)
    type_assert(def, def)
]])
R(C[[
    -- local a = nil
    -- local b = a and a.b or 1
 ]])
R(C[[
    local tbl = {} as {[true] = false}
    tbl[true] = false
    type_assert(tbl[true], false)
 ]])
R(C[[
    local tbl = {} as {1,true,3}
    tbl[1] = 1
    tbl[2] = true
 ]])

R(C[[
    local tbl: {1,true,3} = {1, true, 3}
    tbl[1] = 1
    tbl[2] = true
    tbl[3] = 3
 ]])

R(C[[
    local tbl: {1,true,3} = {1, true, 3}
    tbl[1] = 1
    tbl[2] = true
    tbl[3] = 3
 ]])
R(C[[
    local pl = {IsValid = function(self) end}
    local a = pl:IsValid()
    type_assert(a, nil)
 ]])
R(C[[
    --local a: {[number] = any} = {}
    local a = {}
    a[1] = true
    a[2] = false
    table.insert(a, 1337)
    type_assert(a[3], 1337)
 ]])
R(C[[
    type test = function(name)
         return analyzer:GetValue(name.data, "typesystem")
    end
    local type lol = {}
    type_assert(test("lol"), lol)
]])
R(C[[
    local type lol = {}
    type_assert(require("lol"), lol)
]])
R(C[[
    local tbl = {}
    local test = "asdawd"
    tbl[test] = tbl[test] or {}
    tbl[test] = "1"
    type_assert(tbl[test], nil as "1")
]])
R(C[[
    local function fill(t)
        for i = 1, 10 do
            t[i] = i
        end
    end
    local tbl = {}
    fill(tbl)
]])
R(C[[
    tbl, {a,b} = {a=1,b=2}

    type_assert(tbl.a, nil as 1)
    type_assert(tbl.b, nil as 2)
    type_assert(a, nil as 1)
    type_assert(b, nil as 2)
]])
R(C[[
    local type a = 1
    type_assert(a, 1)
]])
R(C[[
    local a = function(): number,string return 1,"" end
]])
R(C[[
    assert(1 == 1, "lol")
]])
R(C[[
    local function test(a, b)

    end

    test(true, false)
    test(false, true)
    test(1, "")

    local type check = function(func)
        local a = func.data.arg.data[1]
        local b = types.Set:new({
            types.Object:new("number", 1, true),
            types.Object:new("boolean", false, true),
            types.Object:new("boolean", true, true)
        })

        assert(b:SupersetOf(a))
    end

    check(test, "!")
]])

R(C[[
    type_assert(math.floor(1), 1)
]])

R(C[[require("adawdawddwaldwadwadawol")]], "unable to find module")

R(C[[local a = 1 a()]], "number.-cannot be called")

R(C[[
    local a: {[string] = any} = {} -- can assign a string to anything, (most common usage)
    a.lol = "aaa"
    a.lol2 = 2
    a.lol3 = {}
    a[1] = {}
 ]], "invalid key number")
R(C[[
        local {a,b} = nil
    ]], "expected a table on the right hand side, got")
R(C[[
        local a: {[string] = string} = {}
        a.lol = "a"
        a[1] = "a"
    ]], "invalid key number.-expected string")
R(C[[
        local a: {[string] = string} = {}
        a.lol = 1
    ]], "invalid value number.-expected string")
R(C[[
        local a: {} = {}
        a.lol = true
     ]], "invalid key string")
R(C[[
        local tbl: {1,true,3} = {1, true, 3}
        tbl[2] = false
     ]], "invalid value boolean.-expected.-true")
R(C[[
        local tbl: {1,true,3} = {1, false, 3}
    ]], "expected .- but the right hand side is ")
R(C[[
        assert(1 == 2, "lol")
    ]],"lol")

R(C[[
    local a: {} = {}
    a.lol = true
]],"invalid key")

R(C[[
    local a = 1
    a.lol = true
]],"undefined set:")

R(C[[local a = 1; a = a.lol]],"undefined get:")
R(C[[local a = 1 + true]], "no operator for.-number.-%+.-boolean")
