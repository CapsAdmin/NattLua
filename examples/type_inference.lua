local Crawler = require("oh.crawler")

local tests = {
[[
    local a = {}
    a.foo = {}

    local c = 0

    function a:bar()
        type_expect(self, "table")
        c = 1
    end

    a:bar()

    type_expect(c, "number", 1)
]], [[
    local function test()

    end

    type_expect(test, "function")
]], [[
    local a = 1
    repeat
        type_expect(a, "number")
    until false
]], [[
    local c = 0
    for i = 1, 10, 2 do
        type_expect(i, "number")
        if i == 1 then
            c = 1
            break
        end
    end
    type_expect(c, "number", 1)
]], [[
    local a = {foo = true, bar = false, faz = 1}
    for k,v in pairs(a) do
        type_expect(k, "string")
        type_expect(v, {"number", "string"})
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

    type_expect(a, "number", 6)
]], [[
    local a = 1+2+3+4

    local function print(foo)
        return foo
    end

    if a then
        local b = print(a)
    end

    --type_expect(print, "function: any(foo)")
]],  false,[[
    local a
    a = 2

    if true then
        local function foo(lol)
            return foo(lol)
        end
        local complex = foo(a)
        EXPECT(complex, "any(function(lol) return foo(lol) end)")
    end
]], [[
    b = {}
    b.lol = 1

    local a = b

    local function foo(tbl)
        return tbl.lol + 1
    end

    local c = foo(a)
    EXPECT(c, "number(2)")
]], [[
    local META = {}
    META.__index = META

    function META:Test(a,b,c)
        return 1+c,2+b,3+a
    end

    local a,b,c = META:Test(1,2,3)

    --local w = false

    if w then
        local c = a
        EXPECT(c, "number(4)")
    end
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

        EXPECT(a, "number(2)")
    end
]], [[
    for i = 1, 10 do
        EXPECT(i, "number(1..10)")
        if i == 15 then
            break
        end
    end
]], [[
    local function lol(a, ...)
        local lol,foo,bar = ...

        if a == 1 then return 1 end
        if a == 2 then return {} end
        if a == 3 then return "", foo+2,3 end
    end

    local a,b,c = lol(3,1,2,3)

    Expect(a, 'string("")')
    Expect(b, 'number(4)')
    Expect(c, 'number(3)')
]], [[
    function foo(a, b) return a+b end

    local a = foo(1,2)

    Expect(a, "number(3)")
end
]],
[[
    local a = 1
    type_expect(a, "number")
]], [[
local   a,b,c = 1,2,3
        d,e,f = 4,5,6

local   vararg_1 = ...
        vararg_2 = ...

type_expect(vararg_1, "")

local function test(...)
    return a,b,c, ...
end

A, B, C, D = test(), 4

local z,x,y,æ,ø,å = test(4,5,6)
local novalue

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

    type_expect(ag, "string", "hello")

]],[[
    local foo = {lol = 3}
    function foo:bar(a)
        return a+self.lol
    end

    type_expect(foo:bar(2), "number", 5)

]],[[
    function prefix (w1, w2)
        return w1 .. ' ' .. w2
    end

    type_expect(prefix("hello", "world"), "string", "hello world")
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

    type_expect(a, "boolean", false)
    type_expect(b, "boolean", true)
    type_expect(c, "string", "lol")
]],[[
    local func = function()
        local a = 1

        return function()
            return a
        end
    end

    local f = func()

    type_expect(f(), "number", 1)
]],[[
    local function pairs(t)
        local k, v
        return function(v, k)
            local k, v = next(t, k)

            return k,v
        end
    end

    for k,v in pairs({foo=1, bar=2, faz=3}) do
        type_expect(k, "string")
        type_expect(v, "number")
    end
]],[[
    local t = {foo=1, bar=2, faz="str"}
    pairs(t)
    for k,v in pairs(t) do
        type_expect(k, "string")
        type_expect(v, {"string", "number"})
    end
]],[[
    function prefix (w1, w2)
        return w1 .. ' ' .. w2
    end

    local w1,w2 = "foo", "bar"
    local statetab = {["foo bar"] = 1337}

    local test = statetab[prefix(w1, w2)]
    type_expect(test, "number", 1337)
]],[[
    local function test(a)
        --if a > 10 then return a end
        return test(a+1)
    end

    type_expect(test(1), "any")
]],[[
    local function test(a)
        if a > 10 then return a end
        return test(a+1)
    end

    type_expect(test(1), "number")
]]
}


local Lexer = require("oh.lexer")
local Parser = require("oh.parser")

for _, code in ipairs(tests) do
    if code == false then return end
    --local path = "oh/parser.lua"
    --local code = assert(io.open(path)):read("*all")

    local tk = Lexer(code)
    local ps = Parser()

    local tokens = tk:GetTokens()
    local ast = ps:BuildAST(tokens)

    local crawler = Crawler()

    local t = 0
    function crawler:OnEvent(what, ...)

        if what == "create_global" then
            io.write((" "):rep(t))
            io.write(what, " - ")
            local key, val = ...
            io.write(key:Render())
            if val then
                io.write(" = ")
                io.write(tostring(val))
            end
            io.write("\n")
        elseif what == "newindex" then
            io.write((" "):rep(t))
            io.write(what, " - ")
            local obj, key, val = ...
            io.write(tostring(obj.name), "[", self:Hash(key:GetNode()), "] = ", tostring(val))
            io.write("\n")
        elseif what == "mutate_upvalue" then
            io.write((" "):rep(t))
            io.write(what, " - ")
            local key, val = ...
            io.write(self:Hash(key), " = ", tostring(val))
            io.write("\n")
        elseif what == "upvalue" then
            io.write((" "):rep(t))
            io.write(what, "  - ")
            local key, val = ...
            io.write(self:Hash(key))
            if val then
                io.write(" = ")
                io.write(tostring(val))
            end
            io.write("\n")
        elseif what == "set_global" then
            io.write((" "):rep(t))
            io.write(what, " - ")
            local key, val = ...
            io.write(self:Hash(key))
            if val then
                io.write(" = ")
                io.write(tostring(val))
            end
            io.write("\n")
        elseif what == "enter_scope" then
            local node, extra_node = ...
            io.write((" "):rep(t))
            t = t + 1
            if extra_node then
                io.write(extra_node.value)
            else
                io.write(node.kind)
            end
            io.write(" { ")
            io.write("\n")
        elseif what == "leave_scope" then
            local node, extra_node = ...
            t = t - 1
            io.write((" "):rep(t))
            io.write("}")
            --io.write(node.kind)
            if extra_node then
            --  io.write(tostring(extra_node))
            end
            io.write("\n")
        elseif what == "external_call" then
            io.write((" "):rep(t))
            local node, type = ...
            io.write(node:Render(), " - (", tostring(type), ")")
            io.write("\n")
        elseif what == "call" then
            io.write((" "):rep(t))
            --io.write(what, " - ")
            local exp, return_values = ...
            if return_values then
                local str = {}
                for i,v in ipairs(return_values) do
                    str[i] = tostring(v)
                end
                io.write(table.concat(str, ", "))
            end
            io.write(" = ", exp:Render())
            io.write("\n")
        elseif what == "function_spec" then
            local func = ...
            io.write((" "):rep(t))
            io.write(what, " - ")
            io.write(tostring(func))
            io.write("\n")
        elseif what == "return" then
            io.write((" "):rep(t))
            io.write(what, "   - ")
            local values = ...
            if values then
                for i,v in ipairs(values) do
                    io.write(tostring(v), ", ")
                end
            end
            io.write("\n")
        else
            io.write((" "):rep(t))
            print(what .. " - ", ...)
        end
    end

    local T = require("oh.types").Type

    local function add(lib, t)
        local tbl = T("table")
        tbl.value = t
        crawler:DeclareGlobal(lib, tbl)
    end

    crawler:DeclareGlobal("type_expect", T("function", {T"any"}, {T"..."}, function(what, type, value, ...)
        if type:IsType("table") then
            local combined = T(type.value[1].value)
            for i = 2, #type.value do
                combined = combined + T(type.value[i].value)
            end
            type = combined
        end

        local type = type.value


        if not what:IsType(type) then
            error("expected " .. type .. " got " .. tostring(what))
        end

        if value ~= nil and value.value ~= what.value then
            error("expected " .. tostring(value.value) .. " got " .. tostring(what.value))
        end

        return T("boolean", true)
    end))

    crawler:DeclareGlobal("next", T("function", {T"any", T"any"}, {T"any", T"any"}, function(tbl, key)
        local key, val = next(tbl.value)

        return T("string", key), val
    end))

    crawler:DeclareGlobal("pairs", T("function", {T"table"}, {T"table"}, function(tbl)
        local key, val
        return function()
            for k,v in pairs(tbl.value) do
                if type(k) == "string" then
                    k = T("string", k)
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

    add("io", {lines = T("function", {T"string"}, {T"number" + T"nil" + T"string"})})
    add("table", {
        insert = T("function", {T"nil"}, {T"table"}),
        getn = T("function", {T"number"}, {T"table"}),
        })
    add("math", {
        random = T("function", {T"number"}, {T"number"}),
    })
    add("string", {
        find = T("function", {T"number" + T"nil", T"number" + T"nil", T"string" + T"nil"}, {T"string", T"string"}),
        sub = T("function", {T"string"}, {T"number", T"number" + T"nil"}),
    })

    crawler:CrawlStatement(ast)
end