require("nattlua.other.jit_options").SetOptimized()
local INSTRUMENTAL = false
local profiler = require("test.helpers.profiler")

if INSTRUMENTAL then
	profiler.Start("instrumental", {"nattlua/parser/.+", "nattlua/syntax/.+"})
end

local util = require("examples.util")
local lua_code = util.Get10MBLua()
local Lexer = require("nattlua.lexer.lexer").New
local Parser = require("nattlua.parser.parser").New
local Code = require("nattlua.code").New
local code = Code(lua_code, "10mb.lua")
local lexer = Lexer(code)
local tokens = lexer:GetTokens()
collectgarbage("stop")
local count = 0

if INSTRUMENTAL then
	pcall(function()
		Parser(
			tokens,
			code,
			{
				on_parsed_node = function(_, node)
					count = count + 1

					if count > 30000 then error("stopping early") end
				end,
			}
		):ParseRootNode()
	end)

	profiler.Stop()
else
	profiler.Start()

	util.Measure("code:Parse()", function()
		Parser(tokens, code):ParseRootNode()
	end)

	profiler.Stop()
end
