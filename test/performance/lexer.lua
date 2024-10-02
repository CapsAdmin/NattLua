require("nattlua.other.jit_options").SetOptimized()
local Lexer = require("nattlua.lexer").New
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


do
	-- should take around 1.2 seconds
	local tokens = util.Measure("lexer:GetTokens() reading contents of token and parsing strings", function()
		lexer:GetTokens()
	end)
end

do
	-- should take around 0.8 seconds
	local tokens = util.Measure("lexer:ReadSimple() reading only kind, start and stop", function()
		lexer:ResetState()

		while true do
			local type, start, stop, is_whitespace = lexer:ReadSimple()

			if type == "end_of_file" then break end
		end
	end)
end

profiler.Stop()
