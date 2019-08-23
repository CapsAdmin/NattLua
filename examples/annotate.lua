
local oh = require("oh")
local Crawler = require("oh.crawler")
local LuaEmitter = require("oh.lua_emitter")

local code = io.open("oh/lexer.lua"):read("*all")
local base_lib = io.open("oh/base_lib.oh"):read("*all")

code = [[

    local a = 1
    a = math.sin(1)
]]


--code = base_lib .. "\n" .. code

local em = LuaEmitter()
local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code, "test")), "test", code))
--require("oh.util").TablePrint(ast.statements[2], {tokens = "table", whitespace = "table", upvalue_or_global = "table"})
local crawler = Crawler()

function crawler:Index(node)
    print(node:Render())
end

--crawler.OnEvent = crawler.DumpEvent

crawler.code = code
crawler.name = "test"
crawler:CrawlStatement(ast)

--print(em:BuildCode(ast))
