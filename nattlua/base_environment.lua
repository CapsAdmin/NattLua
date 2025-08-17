local Table = require("nattlua.types.table").Table
local Nil = require("nattlua.types.symbol").Nil
local LStringNoMeta = require("nattlua.types.string").LStringNoMeta
local Analyzer = require("nattlua.analyzer.analyzer").New

if not _G.IMPORTS then
	_G.IMPORTS = setmetatable(
		{},
		{
			__index = function(self, key)
				return function()
					return _G["req" .. "uire"](key)
				end
			end,
		}
	)
end

local function import_data(path)
	local f, err = io.open(path, "rb")

	if not f then return nil, err end

	local code = f:read("*all")
	f:close()

	if not code then return nil, path .. " empty file" end

	return code
end

local function load_definitions(root_node)
	local path = "nattlua/definitions/index.nlua"
	local config = {}
	config.file_path = config.file_path or path
	config.file_name = config.file_name or "@" .. path
	config.emitter = {
		comment_type_annotations = false,
	}
	config.parser = {root_statement_override = root_node}
	-- import_data will be transformed on build and the local function will not be used
	-- we canot use the upvalue path here either since this happens at parse time
	local code = assert(import_data("nattlua/definitions/index.nlua"))
	local Compiler = require("nattlua.compiler").New
	return Compiler(code, config.file_name, config)
end

return {
	BuildBaseEnvironment = function(root_node)
		local compiler = load_definitions(root_node)
		-- for debugging
		compiler.is_base_environment = true
		assert(compiler:Lex())
		assert(compiler:Parse())
		local runtime_env = Table()
		runtime_env:SetMutationLimit(math.huge)
		local typesystem_env = Table()
		typesystem_env.string_metatable = Table()
		compiler:SetEnvironments(runtime_env, typesystem_env)
		assert(compiler:Analyze())
		typesystem_env.string_metatable:Set(
			LStringNoMeta("__index"),
			assert(typesystem_env:Get(LStringNoMeta("string")), "failed to find string table")
		)
		return runtime_env, typesystem_env
	end,
}
