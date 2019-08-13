
local oh = require("oh")
local Crawler = require("oh.crawler")
local LuaEmitter = require("oh.lua_emitter")
local types = require("oh.types")

local code = io.open("oh/parser.lua"):read("*all")
local base_lib = io.open("oh/base_lib.oh"):read("*all")

codwe = [==[
    local a = 1
    function b(lol)
        if lol == 1 then return "foo" end
        return lol + 4, true
    end
    local d = b(2)
    local d = b(a)

    function foo(a --[[#:number]], b --[[#:number]])
        return a+b
    end

    local lol: {a: boolean} = {}
    lol.a = true

    function lol:Foo(foo, bar)
        local a = self.a
    end

    local lol: string[] = {}

    local a = table.concat(lol)
]==]

codwe = [[
    interface math {
        sin = function(number): number
    }

    interface math {
        cos = function(number): number
    }

    local a = math.sin(1)
]]

code = [[
    local a = math.cos(1)

    type_assert<a, nil as number>
]]

code = base_lib .. "\n" .. code

local em = LuaEmitter()
local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code, "test")), "test", code))
local crawler = Crawler()

--crawler.OnEvent = crawler.DumpEvent

crawler.code = code
crawler.name = "test"
crawler:CrawlStatement(ast)

--print(em:BuildCode(ast))