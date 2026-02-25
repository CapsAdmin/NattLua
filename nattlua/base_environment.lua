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

local function load_definitions(root_node, parent_config)
	local path = "nattlua/definitions/index.nlua"
	local config = {}

	if parent_config then
		for k, v in pairs(parent_config) do
			config[k] = v
		end
	end

	config.file_path = path
	config.file_name = config.file_name or "@" .. path
	config.root_directory = ROOT_PATH
	config.working_directory = ""
	config.emitter = config.emitter or {}
	config.emitter.comment_type_annotations = false
	config.parser = config.parser or {}
	config.parser.root_statement_override = root_node
	-- import_data will be transformed on build and the local function will not be used
	-- we cannot use the upvalue path here either since this happens at parse time
	local code = import_data("nattlua/definitions/index.nlua")
	local Compiler = require("nattlua.compiler").New
	return Compiler(code, config.file_name, config)
end

local DISABLE = _G.DISABLE_BASE_ENV
local REUSE = _G.REUSE_BASE_ENV
local cached_runtime
local cached_typesystem
local cached_node_map
return {
	BuildBaseEnvironment = function(root_node, parent_analyzer)
		if DISABLE then return Table(), Table(), {} end

		if REUSE and cached_runtime and cached_typesystem then
			return cached_runtime, cached_typesystem, cached_node_map
		end

		local compiler = load_definitions(root_node, parent_analyzer and parent_analyzer.config)
		-- for debugging
		compiler.is_base_environment = true
		assert(compiler:Lex())
		assert(compiler:Parse())
		local runtime_env = Table()
		runtime_env:SetMutationLimit(math_huge)
		local typesystem_env = Table()
		typesystem_env.string_metatable = Table()
		compiler:SetEnvironments(runtime_env, typesystem_env)
		-- Use parent analyzer's config if it exists or just use a fresh analyzer
		local analyzer

		if parent_analyzer then
			analyzer = require("nattlua.analyzer.analyzer").New(parent_analyzer.config)
			analyzer.type_to_node = parent_analyzer.type_to_node
		-- Ensure we're using a common statement count if we want to track it
		-- but for base environment it might be noisy. Let's at least record parsed paths.
		end

		assert(compiler:Analyze(analyzer))

		if parent_analyzer then
			for path, _ in pairs(compiler.analyzer.parsed_paths) do
				parent_analyzer.parsed_paths[path] = true
			end

			parent_analyzer.statement_count = (parent_analyzer.statement_count or 0) + (compiler.analyzer.statement_count or 0)
		end

		typesystem_env.string_metatable:Set(
			LStringNoMeta("__index"),
			assert(typesystem_env:Get(LStringNoMeta("string")), "failed to find string table")
		)

		if REUSE then
			cached_runtime = runtime_env
			cached_typesystem = typesystem_env
			cached_node_map = compiler.analyzer:GetTypeToNodeMap()
		end

		return runtime_env, typesystem_env, compiler.analyzer:GetTypeToNodeMap()
	end,
}
