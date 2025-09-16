local util = require("examples.util")
require("nattlua.other.jit_options").SetOptimized()
util.LoadGithub("GitSparTV/LLLua/master/src/lexer/tokens.lua", "lexer.tokens")
util.LoadGithub("GitSparTV/LLLua/master/src/lexer/chars.lua", "lexer.chars")
util.LoadGithub("GitSparTV/LLLua/master/src/lexer/init.lua", "lllua-lexer")
local Lexer = require("lllua-lexer")
local lua_code = util.Get10MBLua()

util.Measure("LexerSetup", function()
	local lex = Lexer.Setup(lua_code)
	local EOF = -1

	while lex.c ~= EOF do
		Lexer.Next(lex)
	end
end)
