require("nattlua.other.jit_options").SetOptimized()
local profiler = require("test.helpers.profiler")
local Parser = require("nattlua.parser").New
local Lexer = require("nattlua.lexer").New
local Code = require("nattlua.code").New
local util = require("examples.util")
local lua_code = assert(
	util.FetchCode(
		"examples/benchmarks/temp/10mb.lua",
		"https://gist.githubusercontent.com/CapsAdmin/0bc3fce0624a72d83ff0667226511ecd/raw/b84b097b0382da524c4db36e644ee8948dd4fb20/10mb.lua"
	)
)
local code = Code(lua_code, "10mb.lua")
local lexer = Lexer(code)
local tokens = lexer:GetTokens()
profiler.Start()

util.Measure("code:Parse()", function()
	Parser(tokens, code):ParseRootNode()
end)

profiler.Stop()