local Table = require("nattlua.types.table").Table
local LStringNoMeta = require("nattlua.types.string").LStringNoMeta
return
	{
		BuildBaseEnvironment = function()
			if _G.DISABLE_BASE_ENV then return require("nattlua.types.table").Table({}) end
			local nl = require("nattlua")
			local compiler = assert(nl.File("nattlua/definitions/index.nlua"))
			assert(compiler:Lex())
			assert(compiler:Parse())
			local g = Table()
			g.string_metatable = Table()
			compiler:SetDefaultEnvironment(g)
			local base = compiler.Analyzer()
			assert(compiler:Analyze(base))
			g.string_metatable:Set(LStringNoMeta("__index"), g:Get(LStringNoMeta("string")))
			return g
		end,
	}
