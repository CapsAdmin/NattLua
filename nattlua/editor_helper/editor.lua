--DONT_ANALYZE
local Compiler = require("nattlua.compiler").New
local formating = require("nattlua.other.formating")
local Union = require("nattlua.types.union").Union
local Table = require("nattlua.types.table").Table
local runtime_syntax = require("nattlua.syntax.runtime")
local typesystem_syntax = require("nattlua.syntax.typesystem")
local class = require("nattlua.other.class")
local BuildBaseEnvironment = require("nattlua.runtime.base_environment").BuildBaseEnvironment
local runtime_env, typesystem_env = BuildBaseEnvironment()
local path_util = require("nattlua.other.path")
local META = class.CreateTemplate("token")
META:GetSet("WorkingDirectory", "./")

function META:SetWorkingDirectory(dir)
	print("setting working directory to " .. dir)
	self.WorkingDirectory = dir
end

META:GetSet("ConfigFunction", function()
	return
end)

function META:GetProjectConfig(what, path)
	local get_config = self.ConfigFunction
	local config = get_config(path)

	if config then
		local sub_config = config[what] and config[what]()

		if sub_config then
			sub_config.root_directory = config.config_dir
			return sub_config
		end
	end
end

function META.New()
	local self = {
		TempFiles = {},
		LoadedFiles = {},
	}
	setmetatable(self, META)
	return self
end

function META:GetAanalyzerConfig(path)
	local cfg = self:GetProjectConfig("get-analyzer-config", path) or {}

	if cfg.type_annotations == nil then cfg.type_annotations = true end

	if cfg.should_crawl_untyped_functions == nil then
		cfg.should_crawl_untyped_functions = false
	end

	return cfg
end

function META:GetEmitterConfig(path)
	return self:GetProjectConfig("get-emitter-config", path) or
		{
			preserve_whitespace = false,
			string_quote = "\"",
			no_semicolon = true,
			comment_type_annotations = true,
			type_annotations = "explicit",
			force_parenthesis = true,
			skip_import = true,
		}
end

function META:DebugLog(str)
	if self.debug then print(coroutine.running(), str) end
end

do
	function META:GetFile(path)
		path = path_util.Normalize(path)

		if not self.LoadedFiles[path] then
			self:DebugLog("[ " .. path .. " ] is not loaded")
			self:DebugLog("=== these are loaded ===")

			for k, v in pairs(self.LoadedFiles) do
				self:DebugLog("[ " .. k .. " ] is loaded")
			end

			self:DebugLog("===")
			error(path .. " not loaded", 2)
		end

		return self.LoadedFiles[path]
	end

	function META:LoadFile(path, code, tokens)
		path = path_util.Normalize(path)
		self:DebugLog("[ " .. path .. " ] loaded with " .. #tokens .. " tokens")
		self.LoadedFiles[path] = {
			code = code,
			tokens = tokens,
		}
	end

	function META:UnloadFile(path)
		path = path_util.Normalize(path)
		self:DebugLog("[ " .. path .. " ] unloaded")
		self.LoadedFiles[path] = nil
	end
end

do
	function META:SetFileContent(path, code)
		path = path_util.Normalize(path)

		if code then
			self:DebugLog("[ " .. path .. " ] content loaded with " .. #code .. " bytes")
		else
			self:DebugLog("[ " .. path .. " ] content unloaded")
		end

		self.TempFiles[path] = code
	end

	function META:GetFileContent(path)
		path = path_util.Normalize(path)

		if not self.TempFiles[path] then
			self:DebugLog("[ " .. path .. " ] content is not loaded")
			self:DebugLog("=== these are loaded ===")

			for k, v in pairs(self.TempFiles) do
				self:DebugLog("[ " .. k .. " ] content is loaded")
			end

			self:DebugLog("===")
			error(path .. " is not loaded", 2)
		end

		return self.TempFiles[path]
	end
end

function META:Recompile(path, lol, diagnostics)
	local cfg = self:GetAanalyzerConfig(path)
	diagnostics = diagnostics or {}

	if not lol then
		if type(cfg.entry_point) == "table" then
			if self.debug then print("recompiling entry points from: " .. path) end

			for _, path in ipairs(cfg.entry_point) do
				local new_path = path_util.Resolve(path, cfg.root_directory, cfg.working_directory)

				if self.debug then
					print(path, "->", new_path)
					table.print(cfg)
				end

				self:Recompile(new_path, true, diagnostics)
			end

			return
		elseif type(cfg.entry_point) == "string" then
			local path = path_util.Resolve(cfg.entry_point, cfg.root_directory, cfg.working_directory)

			if self.debug then
				print("recompiling entry point: " .. path)
				print(cfg.entry_point, "->", path)
				table.print(cfg)
			end

			self:Recompile(path, true, diagnostics)
			return
		end
	end

	local entry_point = path or cfg.entry_point

	if not entry_point then return false end

	cfg.inline_require = false
	cfg.pre_read_file = function(parser, path)
		if self.TempFiles[path] then return self:GetFileContent(path) end
	end
	cfg.on_read_file = function(parser, path, content)
		if not self.TempFiles[path] then self:SetFileContent(path, content) end
	end
	cfg.on_parsed_file = function(path, compiler)
		self:LoadFile(path, compiler.Code, compiler.Tokens)
	end
	self:DebugLog("[ " .. entry_point .. " ] compiling")
	local compiler = Compiler([[return import("]] .. entry_point .. [[")]], entry_point, cfg)
	compiler.debug = true
	compiler:SetEnvironments(runtime_env, typesystem_env)

	function compiler.OnDiagnostic(_, code, msg, severity, start, stop, node, ...)
		local name = code:GetName()

		if severity == "fatal" then
			self:DebugLog("[ " .. entry_point .. " ] " .. formating.FormatMessage(msg, ...))
		end

		diagnostics[name] = diagnostics[name] or {}
		table.insert(
			diagnostics[name],
			{
				severity = severity,
				code = code,
				start = start,
				stop = stop,
				message = formating.FormatMessage(msg, ...),
				trace = debug.traceback(),
			}
		)
	end

	if compiler:Parse() then
		self:DebugLog("[ " .. entry_point .. " ] parsed with " .. #compiler.Tokens .. " tokens")

		if compiler.SyntaxTree.imports then
			for _, root_node in ipairs(compiler.SyntaxTree.imports) do
				local root = root_node.RootStatement

				if root_node.RootStatement then
					if not root_node.RootStatement.parser then
						root = root_node.RootStatement.RootStatement
					end

					-- if root is false it failed to import and will be reported shortly after
					if root then
						self:SetFileContent(root.parser.config.file_path, root.code:GetString())
						self:LoadFile(root.parser.config.file_path, root.code, root.lexer_tokens)
						diagnostics[root.parser.config.file_path] = diagnostics[root.parser.config.file_path] or {}
					end
				end
			end
		else
			self:SetFileContent(path, compiler.Code:GetString())
			self:LoadFile(path, compiler.Code, compiler.Tokens)
			diagnostics[path] = diagnostics[path] or {}
		end

		local should_analyze = true

		if cfg then
			if entry_point then
				should_analyze = self.TempFiles[entry_point] and
					self:GetFileContent(entry_point):find("-" .. "-ANALYZE", nil, true)
			end

			if not should_analyze and path and path:find("%.nlua$") then
				should_analyze = true
			end
		end

		if should_analyze then
			local ok, err = compiler:Analyze(nil, cfg)
			local name = compiler:GetCode():GetName()

			if not ok then
				diagnostics[name] = diagnostics[name] or {}
				table.insert(
					diagnostics,
					{
						severity = "fatal",
						code = compiler:GetCode(),
						start = 1,
						stop = compiler:GetCode():GetByteSize(),
						message = err,
					}
				)
			end

			self:DebugLog(
				"[ " .. entry_point .. " ] analyzed with " .. (
						diagnostics[name] and
						#diagnostics[name] or
						0
					) .. " diagnostics"
			)
		else
			self:DebugLog("[ " .. entry_point .. " ] skipped analysis")
		end
	end

	for name, data in pairs(diagnostics) do
		self:OnDiagnostics(name, data)
	end
end

function META:OnDiagnostics(name, data) end

function META:OnResponse(response) end

function META:OnRefresh() end

function META:Initialize()
	self:Recompile()
end

function META:Format(code, path)
	local config = self:GetEmitterConfig(path)
	config.comment_type_annotations = path:sub(-#".lua") == ".lua"
	config.transpile_extensions = path:sub(-#".lua") == ".lua"
	local compiler = Compiler(code, "@" .. path, config)
	local code, err = compiler:Emit()
	return code
end

function META:OpenFile(path, code)
	self:SetFileContent(path, code)
	self:Recompile(path)
end

function META:CloseFile(path)
	self:SetFileContent(path, nil)
	self:UnloadFile(path)
end

function META:UpdateFile(path, code)
	self:SetFileContent(path, code)
	self:Recompile(path)
end

function META:SaveFile(path)
	self:SetFileContent(path, nil)
	self:Recompile(path)
end

function META:FindToken(path, line, char)
	local data = self:GetFile(path)
	local sub_pos = data.code:LineCharToSubPos(line + 1, char + 1)

	for _, token in ipairs(data.tokens) do
		if sub_pos >= token.start and sub_pos <= token.stop then
			return token, data
		end
	end

	-- fallback  to the last token
	local token = data.tokens[#data.tokens]

	if token then return token, data end

	error("cannot find token at " .. path .. ":" .. line .. ":" .. char, 2)
end

function META:FindTokensFromRange(
	path--[[#: string]],
	line_start--[[#: number]],
	char_start--[[#: number]],
	line_stop--[[#: number]],
	char_stop--[[#: number]]
)
	local data = self:GetFile(path)
	local sub_pos_start = data.code:LineCharToSubPos(line_start, char_start)
	local sub_pos_stop = data.code:LineCharToSubPos(line_stop, char_stop)
	local found = {}

	for _, token in ipairs(data.tokens) do
		if token.start >= sub_pos_start and token.stop <= sub_pos_stop then
			table.insert(found, token)
		end
	end

	return found
end

do
	local function find_parent(token, type, kind)
		local node = token.parent

		if not node then return nil end

		while node.parent do
			if node.type == type and node.kind == kind then return node end

			node = node.parent
		end

		return nil
	end

	local function find_nodes(tokens, type, kind)
		local nodes = {}
		local done = {}

		for _, token in ipairs(tokens) do
			local node = find_parent(token, type, kind)

			if node and not done[node] then
				table.insert(nodes, node)
				done[node] = true
			end
		end

		return nodes
	end

	function META:GetInlayHints(path, start_line, start_character, stop_line, stop_character)
		local tokens = self:FindTokensFromRange(
			path,
			start_line - 1,
			start_character - 1,
			stop_line - 1,
			stop_character - 1
		)
		local hints = {}
		local assignments = find_nodes(tokens, "statement", "local_assignment")

		for _, assingment in ipairs(find_nodes(tokens, "statement", "assignment")) do
			table.insert(assignments, assingment)
		end

		for _, assignment in ipairs(assignments) do
			if assignment.environment == "runtime" then
				for i, left in ipairs(assignment.left) do
					if not left.tokens[":"] and assignment.right and assignment.right[i] then
						local types = left:GetAssociatedTypes()

						if
							types and
							(
								assignment.right[i].kind ~= "value" or
								assignment.right[i].value.value.type == "letter"
							)
						then
							local data = self:GetCode(path):SubPosToLineChar(left:GetStartStop())
							local label = tostring(Union(types))

							if #label > 20 then label = label:sub(1, 20) .. "..." end

							table.insert(
								hints,
								{
									label = ": " .. label,
									tooltip = label,
									position = {
										lineNumber = data.line_stop,
										column = data.character_stop + 1,
									},
									kind = 1, -- type
								}
							)
						end
					end
				end
			end
		end

		return hints
	end
end

function META:GetCode(path)
	local data = self:GetFile(path)
	return data.code
end

function META:GetRenameInstructions(path, line, character, newName)
	local token, data = self:FindToken(path, line, character)
	local upvalue = token:FindUpvalue()
	local edits = {}

	for i, v in ipairs(data.tokens) do
		local u = v:FindUpvalue()

		if u == upvalue and v.type == "letter" then
			if v.value == token.value then
				table.insert(
					edits,
					{
						start = v.start,
						stop = v.stop,
						from = v.value,
						to = newName,
					}
				)
			end
		end
	end

	return edits
end

function META:GetDefinition(path, line, character)
	local token, data = self:FindToken(path, line, character)
	local types = token:FindType()

	if types[1] then
		if types[1]:GetUpvalue() then
			local node = types[1]:GetUpvalue():GetNode()
			return node
		end

		if types[1].GetFunctionBodyNode and types[1]:GetFunctionBodyNode() then
			local node = types[1]:GetFunctionBodyNode()
			return node
		end

		if types[1].GetNode and types[1]:GetNode() then
			local node = types[1]:GetNode()
			return node
		end
	end
end

function META:GetHover(path, line, character)
	local token
	local ok, err = pcall(function()
		token = self:FindToken(path, line, character)
	end)

	if not ok then return end

	local types, found_parents, scope = token:FindType()
	local obj

	if #types == 1 then obj = types[1] elseif #types > 1 then obj = Union(types) end

	return {
		obj = obj,
		scope = scope,
		found_parents = found_parents,
		token = token,
	}
end

function META:GetReferences(path, line, character)
	local token, data = self:FindToken(path, line, character)
	local types = token:FindType()
	local references = {}

	for _, obj in ipairs(types) do
		local node

		if obj:GetUpvalue() then
			node = obj:GetUpvalue():GetNode()
		elseif obj.GetFunctionBodyNode and obj:GetFunctionBodyNode() then
			node = obj:GetFunctionBodyNode()
		elseif obj:GetNode() then
			node = obj:GetNode()
		end

		if node then table.insert(references, node) end
	end

	return references
end

return META