local Table = require("nattlua.types.table").Table
local LStringNoMeta = require("nattlua.types.string").LStringNoMeta
return {
	BuildBaseEnvironment = function()
		if _G.DISABLE_BASE_ENV then return Table({}), Table({}) end

		local nl = require("nattlua")
		local compiler = assert(nl.File("nattlua/definitions/index.nlua"))
		assert(compiler:Lex())
		assert(compiler:Parse())
		local runtime_env = Table()
		local typesystem_env = Table()
		typesystem_env.string_metatable = Table()
		compiler:SetEnvironments(runtime_env, typesystem_env)
		local base = compiler.Analyzer()
		assert(compiler:Analyze(base))
		typesystem_env.string_metatable:Set(LStringNoMeta("__index"), typesystem_env:Get(LStringNoMeta("string")))
		return runtime_env, typesystem_env
	end,
}
