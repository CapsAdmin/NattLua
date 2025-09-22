local Table = require("nattlua.types.table").Table
local Nil = require("nattlua.types.symbol").Nil
local LStringNoMeta = require("nattlua.types.string").LStringNoMeta
local Analyzer = require("nattlua.analyzer.analyzer").New
local assert = _G.assert
local io_open = _G.io.open
local math_huge = _G.math.huge
local ROOT_PATH = _G.ROOT_PATH

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
	if ROOT_PATH then path = ROOT_PATH .. path end

	local f, err = io_open(path, "rb")

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
	config.root_directory = ROOT_PATH
	config.emitter = {
		comment_type_annotations = false,
	}
	config.parser = {root_statement_override = root_node}
	-- import_data will be transformed on build and the local function will not be used
	-- we cannot use the upvalue path here either since this happens at parse time
	local code = assert(import_data("nattlua/definitions/index.nlua"))
	local Compiler = require("nattlua.compiler").New
	return Compiler(code, config.file_name, config)
end

local DISABLE = _G.DISABLE_BASE_ENV
local REUSE = _G.REUSE_BASE_ENV
local cached_runtime
local cached_typesystem
return {
	BuildBaseEnvironment = function(root_node)
		if DISABLE then return Table(), Table() end

		if REUSE and cached_runtime and cached_typesystem then
			return cached_runtime, cached_typesystem
		end

		local compiler = load_definitions(root_node)
		-- for debugging
		compiler.is_base_environment = true
		assert(compiler:Lex())
		assert(compiler:Parse())
		local runtime_env = Table()
		runtime_env:SetMutationLimit(math_huge)
		local typesystem_env = Table()
		typesystem_env.string_metatable = Table()
		compiler:SetEnvironments(runtime_env, typesystem_env)
		assert(compiler:Analyze())
		typesystem_env.string_metatable:Set(
			LStringNoMeta("__index"),
			assert(typesystem_env:Get(LStringNoMeta("string")), "failed to find string table")
		)

		if REUSE then
			cached_runtime = runtime_env
			cached_typesystem = typesystem_env
		end

		return runtime_env, typesystem_env
	end,
}
