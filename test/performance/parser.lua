require("nattlua.other.jit_options").SetOptimized()
local profiler = require("test.helpers.profiler")
local Parser = require("nattlua.parser.parser").New
local Lexer = require("nattlua.lexer.lexer").New
local Code = require("nattlua.code").New
local util = require("examples.util")
local lua_code = util.Get10MBLua()
local code = Code(lua_code, "10mb.lua")
local lexer = Lexer(code)
local tokens = lexer:GetTokens()
profiler.Start()

util.Measure("code:Parse()", function()
	Parser(tokens, code):ParseRootNode()
end)

profiler.Stop()
