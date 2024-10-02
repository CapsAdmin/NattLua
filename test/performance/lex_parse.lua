require("nattlua.other.jit_options").SetOptimized()
local Lexer = require("nattlua.lexer").New
local Parser = require("nattlua.parser").New
local Code = require("nattlua.code").New
local util = require("examples.util")
local lua_code = assert(
	util.FetchCode(
		"examples/benchmarks/temp/10mb.lua",
		"https://gist.githubusercontent.com/CapsAdmin/0bc3fce0624a72d83ff0667226511ecd/raw/b84b097b0382da524c4db36e644ee8948dd4fb20/10mb.lua"
	)
)
local lexer = Lexer(Code(lua_code, "10mb.lua"))
local profiler = require("test.helpers.profiler")
profiler.Start()
collectgarbage("stop")
do
	-- should take around 1.2 seconds
	local tokens = util.Measure("lexer:GetTokens() reading contents of token and parsing strings", function()
		Parser(lexer:GetTokens(), code):ParseRootNode()
	end)
end
profiler.Stop()
