local Crawler = require("oh.crawler")

local tests = {
    [[
        local a = {}
        a.foo = {}

        function a:bar()

        end

        local function test()

        end

        repeat

        until false

        for i = 1, 10, 2 do
            if i == 1 then
                break
            end
        end

        for k,v in pairs(a) do

        end

        while true do

        end

        do
        end

        if true() then
        elseif false() then
            return false
        else

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
    ]], [[
        local a = 1+2+3+4
        a = false

        local function print(foo)
            return foo
        end

        if a then
            local b = print(a)
        end

        EXPECT(print, "function: any(foo)")
    ]], [[
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
    ]]
}

tests = {[[
local   a,b,c = 1,2,3
        d,e,f = 4,5,6

local   vararg_1 = ...
        vararg_2 = ...

local function test(...)
    return a,b,c, ...
end

A, B, C, D = test(), 4

local z,x,y,æ,ø,å = test(4,5,6)
]]}


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
            io.write(tostring(obj), "[", self:Hash(key), "] = ", tostring(val))
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
        elseif what == "call" then
            io.write((" "):rep(t))
            io.write(what, " - ")
            local exp, return_values = ...
            io.write(exp:Render(), " = ")
            if return_values then
                for i,v in ipairs(return_values) do
                    io.write("(")
                    for i,v in ipairs(v) do
                        io.write(tostring(v), ", ")
                    end
                    io.write(") | ")
                end
            end
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

    crawler.hijack = {}
    function crawler.hijack.Expect(a,b)
        assert(tostring(a) == b.val:sub(2,-2))
    end

    crawler:CrawlStatement(ast)
end