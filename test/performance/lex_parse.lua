require("nattlua.other.jit_options").SetOptimized()
local Lexer = require("nattlua.lexer.lexer").New
local Parser = require("nattlua.parser.parser").New
local Code = require("nattlua.code").New
local util = require("examples.util")
local lua_code = util.Get10MBLua()
local lexer = Lexer(Code(lua_code, "10mb.lua"))
local profiler = require("test.helpers.profiler").New()
collectgarbage("stop")

do
	-- should take around 1.35 seconds
	local tokens = util.Measure("lexer:GetTokens() reading contents of token and parsing strings", function()
		Parser(lexer:GetTokens(), code):ParseRootNode()
	end)
end

profiler:Stop()