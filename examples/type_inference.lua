local Crawler = require("oh.crawler")

local code = [[
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
]]

codew = [[
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
]]

codew = [[
    local a = 1+2+3+4
    a = false

    local function print(foo)
        return foo
    end

    if a then
        local b = print(a)
    end
]]

codew = [[
    local a
    a = 2

    if true then
        local function foo(lol)
            return foo(lol)
        end
        foo(a)
    end
]]

codew = [[
    b = {}
    b.lol = 1

    local a = b

    local function foo(tbl)
        return tbl.lol + 1
    end

    local c = foo(a)
]]

codew = [[
    local META = {}
    META.__index = META

    function META:Test(a,b,c)
        return 1+c,2+b,3+a
    end

    local a,b,c = META:Test(1,2,3)

    --local w = false

    if w then
        local c = a
    end
]]

codew = [[
local function test(a)
    if a then
        return 1
    end

    return false
end

local res = test(true)

if res then
    local a = 1 + res
end
]]

codew = [[
for i = 1, 10 do
    if i == 15 then
        break
    end
end
]]

codew = [[
local function lol(a, ...)
    local lol,foo,bar = ...

    if a == 1 then return 1 end
    if a == 2 then return {} end
    if a == 3 then return "", foo+2,3 end
end

local a,b,c = lol(3,1,2,3)
]]


do
    local Lexer = require("oh.lexer")
    local Parser = require("oh.parser")

    --local path = "oh/parser.lua"
    --local code = assert(io.open(path)):read("*all")

    local tk = Lexer(code)
    local ps = Parser()

    local tokens = tk:GetTokens()
    local ast = ps:BuildAST(tokens)

    local crawler = Crawler()
    crawler:CrawlStatement(ast)
end