require("nattlua.other.jit_options").SetOptimized()
local nl = require("nattlua")
local util = require("examples.util")
local load = loadstring or load
local lua_code = util.Get10MBLua()
local sec = util.MeasureFunction(function()
	local compiler = nl.Compiler(lua_code, "10mb.lua", {parser = {
		skip_import = true,
	}})
	local tokens = util.Measure("compiler:Lex()", function()
		return assert(compiler:Lex()).Tokens
	end)
	local ast = util.Measure("compiler:Parse()", function()
		return assert(compiler:Parse()).SyntaxTree
	end)
	io.write("parsed a total of ", #tokens, " tokens\n")
	io.write("main block of tree contains ", #ast.statements, " statements\n")
end)
print("lexing and parsing took " .. sec .. " seconds")
