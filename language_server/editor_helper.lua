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
local bit = require("nattlua.other.bit")
local class = require("nattlua.other.class")
local fs = require("nattlua.other.fs")
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

function META:GetCompilerConfig(path)
	local cfg = self:GetProjectConfig("get-compiler-config", path) or {}
	cfg.emitter = cfg.emitter or {}
	cfg.analyzer = cfg.analyzer or {}
	cfg.lsp = cfg.lsp or {}
	cfg.parser = cfg.parser or {}

	if cfg.emitter.type_annotations == nil then
		cfg.emitter.type_annotations = true
	end

	if cfg.analyzer.should_crawl_untyped_functions == nil then
		cfg.analyzer.should_crawl_untyped_functions = false
	end

	return cfg
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
		self.LoadedFiles[path] = {
			code = code,
			tokens = tokens,
		}
	end

	function META:UnloadFile(path)
		path = path_util.Normalize(path)
		self.LoadedFiles[path] = nil
	end
end

do
	function META:SetFileContent(path, code)
		path = path_util.Normalize(path)
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
	local cfg = self:GetCompilerConfig(path)
	diagnostics = diagnostics or {}

	if not lol then
		if type(cfg.lsp.entry_point) == "table" then
			if self.debug then print("recompiling entry points from: " .. path) end

			for _, path in ipairs(cfg.lsp.entry_point) do
				local new_path = path_util.Resolve(path, cfg.parser.root_directory, cfg.parser.working_directory)

				if self.debug then
					print(path, "->", new_path)
					table.print(cfg)
				end

				self:Recompile(new_path, true, diagnostics)
			end

			return
		elseif type(cfg.lsp.entry_point) == "string" then
			local path = path_util.Resolve(cfg.lsp.entry_point, cfg.parser.root_directory, cfg.parser.working_directory)

			if self.debug then
				print("recompiling entry point: " .. path)
				print(cfg.lsp.entry_point, "->", path)
				table.print(cfg)
			end

			self:Recompile(path, true, diagnostics)
			return
		end
	end

	local entry_point = path or cfg.lsp.entry_point

	if not entry_point then return false end

	cfg.parser.pre_read_file = function(parser, path)
		if self.TempFiles[path] then return self:GetFileContent(path) end
	end
	cfg.analyzer.pre_read_file = function(parser, path)
		if self.TempFiles[path] then return self:GetFileContent(path) end
	end
	cfg.analyzer.on_read_file = function(parser, path, content)
		if not self.TempFiles[path] then self:SetFileContent(path, content) end
	end
	cfg.analyzer.on_read_file = function(parser, path, content)
		if not self.TempFiles[path] then self:SetFileContent(path, content) end
	end
	cfg.parser.on_parsed_file = function(path, compiler)
		self:LoadFile(path, compiler.Code, compiler.Tokens)
	end
	cfg.parser.inline_require = true
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
			local ok, err = compiler:Analyze(nil, cfg.analyzer)
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

function META:Initialize()
	self:Recompile()
end

function META:Format(code, path)
	local config = self:GetCompilerConfig(path)
	config.emitter = {
		preserve_whitespace = false,
		string_quote = "\"",
		no_semicolon = true,
		comment_type_annotations = true,
		type_annotations = "explicit",
		force_parenthesis = true,
	}
	config.parser = {skip_import = true}
	config.emitter.comment_type_annotations = path:sub(-#".lua") == ".lua"
	config.emitter.transpile_extensions = path:sub(-#".lua") == ".lua"
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

function META:GetAllTokens(path)
	local data = self:GetFile(path)
	return data.tokens
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
	local function find_parent(token, typ, kind)
		local node = token.parent

		if not node then return nil end

		while node.parent do
			if type(typ) == "function" then
				if typ(node) then return node end
			else
				if node.type == typ and node.kind == kind then return node end
			end

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

	function META:GetScopes(path)
		local tokens = self:GetAllTokens(path)
		local statements = find_nodes(tokens, function(node)
			if node.scopes then return node end
		end)
		local scopes = {}

		for _, statement in ipairs(statements) do
			for i, scope in ipairs(statement.scopes) do
				table.insert(scopes, {scope = scope, statement = statement})
			end
		end

		return scopes
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

function META:GetHighlightRanges(path)
	-- find the .coverage file
	local directory = path_util.GetDirectory(path)
	local name = path_util.GetFileName(path)
	local coverage_file = path_util.Join(directory, name .. ".coverage")

	if not fs.is_file(coverage_file) then return end

	local data = loadstring(fs.read(coverage_file))()
	local max_count = 1

	for _, item in ipairs(data) do
		max_count = math.max(max_count, item[3] or 1)
	end

	local ranges = {}

	for _, item in ipairs(data) do
		local count = item[3]
		if count > 0 then
			local normalized = count / max_count
			local r = math.floor(normalized * 255)
			local g = math.floor((1 - normalized) * 255)
			local b = 0
			local color = string.format("#%02x%02x%02x1A", r, g, b)
			table.insert(
				ranges,
				{
					start = item[1],
					stop = item[2],
					backgroundColor = color,
				}
			)
		end
	end

	return ranges
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
	local function build_ast(self, path, node, done)
		done = done or {}

		if done[node] then return end

		done[node] = true

		if type(node) ~= "table" or not node.type or not node.kind then return end

		local root = {
			name = node.type .. "-" .. node.kind,
			detail = tostring(node),
			kind = "Variable",
			children = {},
		}

		for k, v in pairs(node) do
			if type(v) == "table" then
				local child = build(self, path, v, done)

				if child then
					table.insert(root.children, child)
				else
					for i, v in ipairs(v) do
						if type(node) ~= "table" or not node.type or not node.kind then

						else
							local child = build(self, path, v, done)

							if child then table.insert(root.children, child) end
						end
					end
				end
			end
		end

		return root
	end

	local function build_types(self, path, node, obj, env, done)
		done = done or {}

		if done[obj] then
			return {
				name = "*recursive*",
				kind = "Variable",
				children = {},
			}
		end

		done[obj] = true

		if obj.Type == "lexical_scope" then
			local root = {
				name = tostring(obj),
				kind = "Module",
				children = {},
			}

			for _, upvalue in ipairs(obj.upvalues.runtime.list) do
				table.insert(root.children, build(self, path, node, upvalue, "runtime", done))
			end

			for _, upvalue in ipairs(obj.upvalues.typesystem.list) do
				table.insert(root.children, build(self, path, node, upvalue, "typesystem", done))
			end

			for _, obj in ipairs(obj:GetChildren()) do
				table.insert(root.children, build(self, path, node, obj, env, done))
			end

			return root
		elseif obj.Type == "upvalue" then
			local val = obj:GetMutatedValue(obj:GetScope())
			local node2 = obj.statement or node
			local root = {
				name = obj.Key,
				kind = env == "runtime" and "Variable" or "TypeParameter",
				children = {build(self, path, node, val, env, done)},
			}
			return root
		elseif obj.Type == "symbol" then
			local node2 = obj.statement or node
			local root = {
				name = tostring(obj),
				kind = "Enum",
				children = {},
			}
			return root
		elseif obj.Type == "union" then
			local node2 = obj.statement or node
			local root = {
				name = tostring(obj),
				kind = "Namespace",
				children = {},
			}

			for _, obj in ipairs(obj:GetData()) do
				table.insert(root.children, build(self, path, node, obj, env, done))
			end

			return root
		elseif obj.Type == "tuple" then
			local node2 = obj.statement or node
			local root = {
				name = tostring(obj),
				kind = "Array",
				children = {},
			}

			for _, obj in ipairs(obj:GetData()) do
				table.insert(root.children, build(self, path, node, obj, env, done))
			end

			return root
		elseif obj.Type == "table" then
			local node2 = obj.statement or node
			local root = {
				name = tostring(obj),
				kind = "Array",
				children = {},
			}

			for _, kv in ipairs(obj:GetData()) do
				local field = {
					name = tostring(kv.key) .. " = " .. tostring(kv.val),
					detail = tostring(node),
					kind = "Variable",
					children = {
						build(self, path, node, kv.key, env, done),
						build(self, path, node, kv.val, env, done),
					},
				}
				table.insert(root.children, field)
			end

			return root
		elseif obj.Type == "number" then
			local node2 = obj.statement or node
			local root = {
				name = tostring(obj),
				kind = "Number",
				children = {},
			}
			return root
		elseif obj.Type == "range" then
			local node2 = obj.statement or node
			local root = {
				name = tostring(obj),
				kind = "Number",
				children = {},
			}
			return root
		elseif obj.Type == "string" then
			local node2 = obj.statement or node
			local root = {
				name = tostring(obj),
				kind = "String",
				children = {},
			}
			return root
		elseif obj.Type == "any" then
			local node2 = obj.statement or node
			local root = {
				name = tostring(obj),
				kind = "TypeParameter",
				children = {},
			}
			return root
		elseif obj.Type == "function" then
			local node2 = obj.statement or node
			local root = {
				name = tostring(obj),
				kind = "Function",
				children = {},
			}
			table.insert(root.children, build(self, path, node, obj:GetInputSignature(), env, done))
			table.insert(root.children, build(self, path, node, obj:GetOutputSignature(), env, done))
			return root
		else
			error("nyi type: " .. obj.Type)
		end
	end

	local function build_scopes(self, path, node, obj, env)
		if obj.Type == "lexical_scope" then
			local root = {
				name = tostring(obj),
				kind = "Module",
				range = get_range(self:GetCode(path), (obj.node or node):GetStartStop()),
				selectionRange = get_range(self:GetCode(path), (obj.node or node):GetStartStop()),
				children = {},
			}

			for _, upvalue in ipairs(obj.upvalues.runtime.list) do
				table.insert(root.children, build_scopes(self, path, node, upvalue, "runtime", done))
			end

			for _, upvalue in ipairs(obj.upvalues.typesystem.list) do
				table.insert(root.children, build_scopes(self, path, node, upvalue, "typesystem", done))
			end

			for _, obj in ipairs(obj:GetChildren()) do
				table.insert(root.children, build_scopes(self, path, node, obj, env, done))
			end

			return root
		elseif obj.Type == "upvalue" then
			local val = obj:GetMutatedValue(obj:GetScope())
			local node2 = obj.statement or node
			local root = {
				name = obj.Key .. " = " .. tostring(val),
				kind = env == "runtime" and "Variable" or "TypeParameter",
				children = {},
			}
			return root
		else
			error("nyi type: " .. obj.Type)
		end
	end

	local function build_nodes(self, path, node)
		if node.type == "statement" then
			if node.kind == "root" then
				local scope = node.scopes and node.scopes[#node.scopes]
				local str = "\n" .. tostring(scope) .. "\n"
				local root = {
					name = tostring(node) .. str,
					kind = "Module",
					children = {},
					node = node,
				}

				if scope then
					for _, upvalue in ipairs(scope.upvalues.runtime.list) do
						table.insert(root.children, build_scopes(self, path, node, upvalue, "runtime", done))
					end

					for _, upvalue in ipairs(scope.upvalues.typesystem.list) do
						table.insert(root.children, build_scopes(self, path, node, upvalue, "typesystem", done))
					end
				end

				return root
			else

			--error("nyi type: " .. obj.Type)
			end
		end
	end

	function META:GetSymbolTree(path)
		local tokens = self:GetAllTokens(path)

		if not tokens then return {} end

		local root_node
		local node = tokens[1]

		if node then
			while node.parent do
				node = node.parent
			end

			root_node = node
		end

		return {
			build_nodes(self, path, root_node),
		}
	end
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
				elseif obj.Type == "range" then
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
