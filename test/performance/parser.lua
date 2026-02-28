require("nattlua.other.jit_options").SetOptimized()
local INSTRUMENTAL = false
local profiler_module = require("test.helpers.profiler")
local profiler

if INSTRUMENTAL then
	profiler = profiler_module.New({id = "instrumental", filter = {"nattlua/parser/.+", "nattlua/syntax/.+"}})
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
				skip_import = true,
				on_parsed_node = function(_, node)
					count = count + 1

					if count > 30000 then error("stopping early") end
				end,
			}
		):ParseRootNode()
	end)

	if profiler then profiler:Stop() end
else
	profiler = profiler_module.New()

	util.Measure("code:Parse()", function()
		Parser(tokens, code, {skip_import = true}):ParseRootNode()
	end)

	profiler:Stop()
end

os.exit()