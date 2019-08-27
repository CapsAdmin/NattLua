
local oh = require("oh")
local Crawler = require("oh.crawler")
local LuaEmitter = require("oh.lua_emitter")

local code = io.open("oh/lexer.lua"):read("*all")

code = [[
local a = math.sin(1)
]]

local em = LuaEmitter()
local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code, "test")), "test", code))

local crawler = Crawler()

crawler.OnEvent = crawler.DumpEvent

crawler.code = code
crawler.name = "test"
crawler:CrawlStatement(ast)

--print(em:BuildCode(ast))
