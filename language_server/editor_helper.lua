--DONT_ANALYZE
local pairs = _G.pairs
local ipairs = _G.ipairs
local type = _G.type
local table = _G.table
local setmetatable = _G.setmetatable
local pcall = _G.pcall
local debug = _G.debug
local Compiler = require("nattlua.compiler").New
local formating = require("nattlua.other.formating")
local Union = require("nattlua.types.union").Union
local Table = require("nattlua.types.table").Table
local runtime_syntax = require("nattlua.syntax.runtime")
local typesystem_syntax = require("nattlua.syntax.typesystem")
local class = require("nattlua.other.class")
local BuildBaseEnvironment = require("nattlua.base_environment").BuildBaseEnvironment
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
		debug = false,
		node_to_type = {},
	}
	setmetatable(self, META)
	return self
end

function META:NodeToType(typ)
	return self.node_to_type[typ]
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
	function META:IsLoaded(path)
		path = path_util.Normalize(path)
		return self.LoadedFiles[path] ~= nil
	end

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
					self:IsLoaded(entry_point) and
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
					diagnostics[name],
					{
						severity = "fatal",
						code = compiler:GetCode(),
						start = 1,
						stop = compiler:GetCode():GetByteSize(),
						message = err,
					}
				)
			end

			for typ, node in pairs(compiler.analyzer:GetTypeToNodeMap()) do
				self.node_to_type[node] = typ
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
	line = line + 1
	char = char + 1
	local data = self:GetFile(path)
	local sub_pos = data.code:LineCharToSubPos(line, char)

	for i, token in ipairs(data.tokens) do
		if sub_pos >= token.start and sub_pos <= token.stop + 1 then
			return token, data
		end
	end

	print(
		"cannot find token at " .. path .. ":" .. line .. ":" .. char .. " or sub pos " .. sub_pos
	)
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
		local tokens = self:FindTokensFromRange(path, start_line, start_character, stop_line, stop_character)
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
							#types > 0 and
							(
								assignment.right[i].kind ~= "value" or
								assignment.right[i].value.value.type == "letter"
							)
						then
							local start, stop = left:GetStartStop()
							local label = #types == 1 and tostring(types[1]) or tostring(Union(types))

							if #label > 20 then label = label:sub(1, 20) .. "..." end

							table.insert(
								hints,
								{
									label = label,
									start = start,
									stop = stop,
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

	if not token then return end

	local upvalue = token:FindUpvalue()
	local edits = {}

	if not upvalue then
		table.insert(
			edits,
			{
				start = token.start,
				stop = token.stop,
				from = token.value,
				to = newName,
			}
		)
		return edits
	end

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
	local token = self:FindToken(path, line, character)

	if not token then return end

	local types = token:FindType()

	if not types[1] then return end

	for i, typ in ipairs(types) do
		if typ:GetUpvalue() then
			local node = self:NodeToType(typ:GetUpvalue())

			if node then return node end
		end

		if typ.GetFunctionBodyNode and typ:GetFunctionBodyNode() then
			local node = typ:GetFunctionBodyNode()

			if node then return node end
		end

		local node = self:NodeToType(typ)

		if node then return node end
	end
end

function META:GetHover(path, line, character)
	local token = self:FindToken(path, line, character)

	if not token then return end

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
	local token = self:FindToken(path, line, character)

	if not token then return end

	local types = token:FindType()
	local references = {}

	for _, obj in ipairs(types) do
		local node

		if obj:GetUpvalue() then
			node = self:NodeToType(obj:GetUpvalue())
		elseif obj.GetFunctionBodyNode and obj:GetFunctionBodyNode() then
			node = obj:GetFunctionBodyNode()
		elseif self:NodeToType(obj) then
			node = self:NodeToType(obj)
		end

		if node then table.insert(references, node) end
	end

	return references
end

do
	local tokenTypeMap = {}
	local tokenModifiersMap = {}
	local SemanticTokenTypes = {
		-- identifiers or reference
		"class", -- a class type. maybe META or Meta?
		"typeParameter", -- local type >foo< = true
		"parameter", -- function argument: function foo(>a<)
		"variable", -- a local or global variable.
		"property", -- a member property, member field, or member variable.
		"enumMember", -- an enumeration property, constant, or member. uppercase variables and global non tables? local FOO = true ?
		"event", --  an event property.
		"function", -- local or global function: local function >foo<
		"method", --  a member function or method: string.>bar<()
		"type", -- misc type
		-- tokens
		"comment", -- 
		"string", -- 
		"keyword", -- 
		"number", -- 
		"regexp", -- regular expression literal.
		"operator", --
		"decorator", -- decorator syntax, maybe for @Foo in tables, $ and §
		-- other identifiers or references
		"namespace", -- namespace, module, or package.
		"enum", -- 
		"interface", --
		"struct", -- 
		"decorator", -- decorators and annotations.
		"macro", --  a macro.
		"label", --  a label. ??
	}
	local SemanticTokenModifiers = {
		"declaration", -- For declarations of symbols.
		"definition", -- For definitions of symbols, for example, in header files.
		"readonly", -- For readonly variables and member fields (constants).
		"static", -- For class members (static members).
		"private", -- For class members (static members).
		"deprecated", -- For symbols that should no longer be used.
		"abstract", -- For types and member functions that are abstract.
		"async", -- For functions that are marked async.
		"modification", -- For variable references where the variable is assigned to.
		"documentation", -- For occurrences of symbols in documentation.
		"defaultLibrary", -- For symbols that are part of the standard library.
	}

	for i, v in ipairs(SemanticTokenTypes) do
		tokenTypeMap[v] = i - 1
	end

	for i, v in ipairs(SemanticTokenModifiers) do
		tokenModifiersMap[v] = i - 1
	end

	local function get_semantic_type(token)
		if token.parent then
			if token.type == "symbol" and token.parent.kind == "function_signature" then
				return "keyword"
			end

			if
				runtime_syntax:IsNonStandardKeyword(token) or
				typesystem_syntax:IsNonStandardKeyword(token)
			then
				-- check if it's used in a statement, because foo.type should not highlight
				if token.parent and token.parent.type == "statement" then
					return "keyword"
				end
			end
		end

		if runtime_syntax:IsKeywordValue(token) or typesystem_syntax:IsKeywordValue(token) then
			return "type"
		end

		if
			token.value == "." or
			token.value == ":" or
			token.value == "=" or
			token.value == "or" or
			token.value == "and" or
			token.value == "not"
		then
			return "operator"
		end

		if runtime_syntax:IsKeyword(token) or typesystem_syntax:IsKeyword(token) then
			return "keyword"
		end

		if
			runtime_syntax:GetTokenType(token):find("operator", nil, true) or
			typesystem_syntax:GetTokenType(token):find("operator", nil, true)
		then
			return "operator"
		end

		if token.type == "symbol" then return "keyword" end

		do
			local obj
			local types = token:FindType()

			if #types == 1 then obj = types[1] elseif #types > 1 then obj = Union(types) end

			if obj then
				local mods = {}

				if obj:IsLiteral() then table.insert(mods, "readonly") end

				if obj.Type == "union" then
					if obj:IsTypeExceptNil("number") then
						return "number", mods
					elseif obj:IsTypeExceptNil("string") then
						return "string", mods
					elseif obj:IsTypeExceptNil("symbol") then
						return "enumMember", mods
					end

					return "event"
				end

				if obj.Type == "number" then
					return "number", mods
				elseif obj.Type == "string" then
					return "string", mods
				elseif obj.Type == "tuple" or obj.Type == "symbol" then
					return "enumMember", mods
				elseif obj.Type == "any" then
					return "regexp", mods
				end

				if obj.Type == "function" then return "function", mods end

				local parent = obj:GetParent()

				if parent then
					if obj.Type == "function" then
						return "macro", mods
					else
						if obj.Type == "table" then return "class", mods end

						return "property", mods
					end
				end

				if obj.Type == "table" then return "class", mods end
			end
		end

		if token.type == "number" then
			return "number"
		elseif token.type == "string" then
			return "string"
		end

		if token.parent then
			if
				token.parent.kind == "value" and
				token.parent.parent.kind == "binary_operator" and
				(
					token.parent.parent.value and
					token.parent.parent.value.value == "." or
					token.parent.parent.value.value == ":"
				)
			then
				if token.value:sub(1, 1) == "@" then return "decorator" end
			end

			if token.type == "letter" and token.parent.kind:find("function", nil, true) then
				return "function"
			end

			if
				token.parent.kind == "value" and
				token.parent.parent.kind == "binary_operator" and
				(
					token.parent.parent.value and
					token.parent.parent.value.value == "." or
					token.parent.parent.value.value == ":"
				)
			then
				return "property"
			end

			if token.parent.kind == "table_key_value" then return "property" end

			if token.parent.standalone_letter then
				if token.parent.environment == "typesystem" then return "type" end

				if _G[token.value] then return "namespace" end

				return "variable"
			end

			if token.parent.is_identifier then
				if token.parent.environment == "typesystem" then return "typeParameter" end

				return "variable"
			end
		end

		return "comment"
	end

	function META:GetSemanticTokens(path)
		if not self:IsLoaded(path) then return {} end

		local data = self:GetFile(path)
		local integers = {}
		local last_y = 0
		local last_x = 0

		for _, token in ipairs(data.tokens) do
			if token.type ~= "end_of_file" then
				local type, modifiers = get_semantic_type(token)

				if type then
					local data = data.code:SubPosToLineChar(token.start, token.stop)
					local len = #token.value
					local y = (data.line_start - 1) - last_y
					local x = (data.character_start - 1) - last_x

					-- x is not relative when there's a new line
					if y ~= 0 then x = data.character_start - 1 end

					if x >= 0 and y >= 0 then
						table.insert(integers, y)
						table.insert(integers, x)
						table.insert(integers, len)
						assert(tokenTypeMap[type], "invalid type " .. type)
						table.insert(integers, tokenTypeMap[type])
						local result = 0

						if modifiers then
							for _, mod in ipairs(modifiers) do
								assert(tokenModifiersMap[mod], "invalid modifier " .. mod)
								result = bit.bor(result, bit.lshift(1, tokenModifiersMap[mod])) -- TODO, doesn't seem to be working
							end
						end

						table.insert(integers, result)
						last_y = data.line_start - 1
						last_x = data.character_start - 1
					end
				end
			end
		end

		return integers
	end
end

return META
