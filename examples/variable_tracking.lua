local util = require("oh.util")
local oh = require("oh.oh")
local path = "oh/parser.lua"
local code = assert(io.open(path)):read("*all")

code = [[
    local a = {}
    a.b.c = true

    function a.b.c:bar()

    end

    local b = {}
    lol[b] = true
    foo = true

    local foo = {}
    function foo.test()

    end

    foo = true
    local foo
    foo = 1
    function test(a,b,c) end
    local function test(a,b,c) end
    for i = 1, 10 do end

    while foo do foo = true end

    if a then

    elseif b then

    else

    end

    do
        local a = 1
    end

    do
        print(a)
    end

    repeat
        local aaa = 1
    until aaa

    local meta = {}
    function meta:test(a)
        return run(a)
    end
]]

code = [[
    local i = 1
    local b = function() i = i +1 end
]]

local tk = oh.Tokenizer(code)
local ps = oh.Parser()

local tokens = tk:GetTokens()
local ast = ps:BuildAST(tokens)
local anl = oh.Analyzer()

anl:Walk(ast)
print(anl:DumpScope())