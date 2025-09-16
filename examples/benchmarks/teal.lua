require("nattlua.other.jit_options").SetOptimized()
local util = require("examples.util")
local lua_code = util.Get10MBLua()
local tl = util.LoadGithub("teal-language/tl/master/tl.lua", "tl")
local sec = util.MeasureFunction(function()
	local tokens
	local ast

	util.Measure("tl.lex()", function()
		tokens = assert(tl.lex(lua_code))
	end)

	util.Measure("tl.parse_program()", function()
		ast = assert(tl.parse_program(tokens))
	end)
end)
print("lexing and parsing took " .. sec .. " seconds")
