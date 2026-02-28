local INSTRUMENTAL = false
require("nattlua.other.jit_options").SetOptimized()
local util = require("examples.util")
local profiler_module = require("test.helpers.profiler")
local profiler
local lua_code = util.Get10MBLua()

-- this must be called before loading modules since it injects line hooks into the code
if INSTRUMENTAL then
	profiler = profiler_module.New({id = "instrumental", filter = {"nattlua/lexer/.+"}})
end

local Lexer = require("nattlua.lexer.lexer").New
local Code = require("nattlua.code").New
local lexer = Lexer(Code(lua_code, "10mb.lua"))
collectgarbage("stop")

if INSTRUMENTAL then
	-- much slower than sampling profiler
	for i = 1, 100000 do
		local type = lexer:ReadSimple()

		if type == "end_of_file" then break end
	end
else
	profiler = profiler_module.New()

	do
		-- should take around 1.2 seconds
		local tokens = util.Measure("lexer:GetTokens() reading contents of token and parsing strings", function()
			lexer:GetTokens()
		end)
	end

	if true then
		-- should take around 0.8 seconds
		local tokens = util.Measure("lexer:ReadSimple() reading only kind, start and stop", function()
			lexer:ResetState()

			while true do
				local type = lexer:ReadSimple()

				if type == "end_of_file" then break end
			end
		end)
	end
end

if profiler then profiler:Stop() end

os.exit()