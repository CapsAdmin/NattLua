--DONT_ANALYZE
--[[HOTRELOAD
	run_test("test/tests/editor_helper.lua")
	--os.execute("luajit nattlua.lua build fast && luajit nattlua.lua install")
]]
local pairs = _G.pairs
local ipairs = _G.ipairs
local type = _G.type
local table = _G.table
local setmetatable = _G.setmetatable
local pcall = _G.pcall
local debug = _G.debug
local assert = _G.assert
local Compiler = require("nattlua.compiler").New
local formating = require("nattlua.other.formating")
local Union = require("nattlua.types.union").Union
local Table = require("nattlua.types.table").Table
local runtime_syntax = require("nattlua.syntax.runtime")
local typesystem_syntax = require("nattlua.syntax.typesystem")
local callstack = require("nattlua.other.callstack")
local bit = require("nattlua.other.bit")
local class = require("nattlua.other.class")
local fs = require("nattlua.other.fs")
local BuildBaseEnvironment = require("nattlua.base_environment").BuildBaseEnvironment
local runtime_env, typesystem_env = BuildBaseEnvironment()
local path_util = require("nattlua.other.path")
local Token = require("nattlua.lexer.token")
local META = class.CreateTemplate("editor_helper")
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
	return META.NewObject(
		{
			TempFiles = {},
			LoadedFiles = {},
			debug = false,
			node_to_type = {},
		},
		true
	)
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

			local ok = true
			local reasons = {}

			for _, path in ipairs(cfg.lsp.entry_point) do
				local new_path = path_util.Resolve(path, cfg.parser.root_directory, cfg.parser.working_directory)

				if self.debug then
					print(path, "->", new_path)
					table.print(cfg)
				end

				local b, reason = self:Recompile(new_path, true, diagnostics)

				if not b then
					ok = false
					table.insert(reasons, reason)
				end
			end

			return ok, table.concat(reasons, "\n")
		elseif type(cfg.lsp.entry_point) == "string" then
			local path = path_util.Resolve(cfg.lsp.entry_point, cfg.parser.root_directory, cfg.parser.working_directory)

			if self.debug then
				print("recompiling entry point: " .. path)
				print(cfg.lsp.entry_point, "->", path)
				table.print(cfg)
			end

			return self:Recompile(path, true, diagnostics)
		end
	end

	local entry_point = path or cfg.lsp.entry_point

	if not entry_point then return false, "no entry point" end

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
		local str_msg = formating.FormatMessage(msg, ...)

		if severity == "fatal" then
			self:DebugLog("[ " .. entry_point .. " ] " .. str_msg)
		end

		diagnostics[name] = diagnostics[name] or {}
		table.insert(
			diagnostics[name],
			{
				severity = severity,
				code = code,
				start = start,
				stop = stop,
				message = str_msg,
				trace = callstack.traceback(),
			}
		)
	end

	local ok, err = compiler:Parse()

	if not ok then print("FAILED TO PARSE", path, err) end

	if ok then
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
				local node = cfg.analyzer and
					cfg.analyzer.GetCurrentExpression and
					(
						cfg.analyzer:GetCurrentExpression() or
						cfg.analyzer:GetCurrentStatement()
					)
				local start, stop = 1, compiler:GetCode():GetByteSize()

				if node then start, stop = node:GetStartStop() end

				table.insert(
					diagnostics[name],
					{
						severity = "fatal",
						code = compiler:GetCode(),
						start = start,
						stop = stop,
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
		if #data > 0 then self:OnDiagnostics(name, data) end
	end

	return true
end

function META:GetEnvironment()
	return runtime_env, typesystem_env
end

function META:OnDiagnostics(name, data) end

function META:OnResponse(response) end

function META:Initialize()
	local ok, reason = self:Recompile()

	if not ok and reason ~= "no entry point" then
		if not _G.TEST then print(":Recompile() failed: " .. reason) end
	end
end

function META:Format(code, path)
	local config = self:GetCompilerConfig(path)
	config.emitter = {
		pretty_print = true,
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
	assert(self:Recompile(path))
end

function META:CloseFile(path)
	self:SetFileContent(path, nil)
	self:UnloadFile(path)
end

function META:UpdateFile(path, code)
	self:SetFileContent(path, code)
	assert(self:Recompile(path))
end

function META:SaveFile(path)
	self:SetFileContent(path, nil)
	assert(self:Recompile(path))
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
	local function find_parent(token, typ)
		local node = token.parent

		if not node then return nil end

		while node.parent do
			if type(typ) == "function" then
				if typ(node) then return node end
			else
				if node.Type == typ then return node end
			end

			node = node.parent
		end

		return nil
	end

	local function find_nodes(tokens, type)
		local nodes = {}
		local done = {}

		for _, token in ipairs(tokens) do
			local node = find_parent(token, type)

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
		local assignments = find_nodes(tokens, "statement_local_assignment")

		for _, assingment in ipairs(find_nodes(tokens, "statement_assignment")) do
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
								assignment.right[i].Type ~= "expression_value" or
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

	local str = token:GetValueString()
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
			if v:ValueEquals(str) then
				table.insert(
					edits,
					{
						start = v.start,
						stop = v.stop,
						from = str,
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

		if typ.Type == "function" then
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

do
	local runtime_syntax = require("nattlua.syntax.runtime")
	local LString = require("nattlua.types.string").LString

	local function tostring_key(obj)
		if obj.Type == "string" and obj:IsLiteral() then return obj:GetData() end

		return tostring(obj)
	end

	local function tostring_val(obj)
		local str = tostring(obj)

		if #str > 100 then return str:sub(1, 100) .. "..." end

		return str
	end

	local function get_key_values(self, obj, scope, runtime)
		if not obj or obj.Type == "any" then
			local r, t = self:GetEnvironment()
			local tbl = {}

			for key, data in pairs(get_key_values(self, r, scope, runtime)) do
				tbl[key] = data
			end

			for key, data in pairs(get_key_values(self, t, scope, runtime)) do
				tbl[key] = data
			end

			for keyword in pairs(runtime_syntax.Keywords) do
				tbl[keyword] = {val = keyword, obj = "keyword"}
			end

			for keyword in pairs(runtime_syntax.NonStandardKeywords) do
				tbl[keyword] = {val = keyword, obj = "keyword"}
			end

			if scope then
				for key, upvalue in pairs(scope:GetAllVisibleUpvalues()) do
					tbl[key] = {val = key, obj = upvalue}
				end
			end

			for _, typ in ipairs({"string", "number", "any", "true", "nil", "false"}) do
				tbl[typ] = {val = typ, obj = "keyword"}
			end

			return tbl
		end

		if obj.Type == "table" then
			local out = {}

			for _, kv in ipairs(obj:GetData()) do
				local key = tostring_key(kv.key)
				local val = tostring_val(kv.val)
				out[key] = {val = val, obj = kv.val}
			end

			if obj:GetContract() and obj:GetContract() ~= obj then
				for _, kv in ipairs(obj:GetContract():GetData()) do
					local key = tostring_key(kv.key)
					local val = tostring_val(kv.val)
					out[key] = {val = val, obj = kv.val}
				end
			end

			if obj:GetMetaTable() then
				local t = obj:GetMetaTable():Get(LString("__index"))

				if t and t.Type == "table" and t ~= obj then
					for _, kv in ipairs(t:GetData()) do
						local key = tostring_key(kv.key)
						local val = tostring_val(kv.val)
						out[key] = {val = val, obj = kv.val}
					end
				end
			end

			return out
		elseif obj.Type == "string" then
			return get_key_values(self, obj:GetMetaTable():Get(LString("__index")), scope, runtime)
		elseif obj.Type == "tuple" then
			if runtime then
				return get_key_values(self, obj:GetFirstValue(), scope, runtime)
			end
		elseif obj.Type == "union" then
			local out = {}

			for _, obj in ipairs(obj:GetData()) do
				for key, data in pairs(get_key_values(self, obj, scope, runtime)) do
					out[key] = data
				end
			end

			return out
		end

		return nil
	end

	function META:GetKeyValuesForCompletion(path, line, character)
		local data = self:GetHover(path, line, character)
		print(data.token, data.obj, "<< autocompleting")
		return get_key_values(self, data and data.obj, data.scope, false), data
	end
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

		if type(node) ~= "table" or not node.Type then return end

		local root = {
			name = node.Type,
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
						if type(node) ~= "table" or not node.Type then

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
		if node.is_statement then
			if node.Type == "statement_root" then
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

	local types = {
		keyword = "keyword",
		comment = "comment",
		operator = "keyword",
		type = "type",
		symbol = "enumMember",
		number = "number",
		string = "string",
		variable = "variable",
		any = "regexp",
		table = "class",
		func = "function",
	}

	local function get_semantic_type(token)
		if token.type == "fake" then return "string" end

		if token.type == "end_of_file" or token.type == "space" then return end

		if token.type == "multiline_comment" or token.type == "line_comment" then
			return types.comment
		end

		if token:IsKeywordValue() then return types.symbol end

		if token:IsKeyword() then return types.keyword end

		if token:IsUnreachable() then return types.any, {"deprecated"} end

		if token:IsOperator() then return types.operator end

		if token:IsString() then
			return types.string
		elseif token:IsNumber() then
			return types.number
		elseif token:IsTable() then
			return types.table
		elseif token:IsFunction() then
			return types.func
		elseif token:IsSymbol() then
			return types.symbol
		elseif token:IsOtherType() then
			return types.type
		elseif token:IsAny() then
			return types.any
		end

		return types.variable
	end

	local function is_probably_lua(str)
		local possible_statements = {
			"%s*local%s",
			"%s*return%s",
			"%s*while%s",
			"%s*repeat%s",
			"%s*function%s",
			"%s*do%s",
			"%s*if%s",
			"%s*for%s",
			"%s*[a-Z][a-Z0-9]*%s*=",
		}

		for _, word in ipairs(possible_statements) do
			if str:find(word, 0) then return true end
		end

		return false
	end

	function META:GetSemanticTokens(path)
		if not self:IsLoaded(path) then return {} end

		local data = self:GetFile(path)
		local integers = {}
		local last_y = 0
		local last_x = 0

		local function is_lua(str)
			if str:find("return%s", nil) then return true end

			if str:find("local%s", nil) then return true end

			if str:find("%s=%s", nil) then return true end

			if str:find(";", nil, true) then return true end

			return false
		end

		local stringx = require("nattlua.other.string")

		local function process_token(token)
			local type, modifiers = get_semantic_type(token)

			if not type then return end

			assert(tokenTypeMap[type], "invalid type " .. type)
			local pos_data = data.code:SubPosToLineChar(token.start, token.stop)
			local modifier_result = 0

			if modifiers then
				for _, mod in ipairs(modifiers) do
					assert(tokenModifiersMap[mod], "invalid modifier " .. mod)
					modifier_result = bit.bor(modifier_result, bit.lshift(1, tokenModifiersMap[mod]))
				end
			end

			local lines = stringx.split(token:GetValueString(), "\n")
			local line_start = pos_data.line_start - 1
			local line_stop = pos_data.line_stop - 1
			local char_start = pos_data.character_start - 1
			local char_stop = pos_data.character_stop - 1
			--
			local start_line = table.remove(lines, 1)
			local middle_lines

			if #lines > 1 then middle_lines = lines end

			if start_line then
				local len = #start_line
				local y = line_start - last_y
				local x = char_start - last_x

				if y ~= 0 then x = char_start end

				if x >= 0 and y >= 0 then
					table.insert(integers, y)
					table.insert(integers, x)
					table.insert(integers, len)
					table.insert(integers, tokenTypeMap[type])
					table.insert(integers, modifier_result)
					last_y = line_start
					last_x = char_start
				end
			end

			if middle_lines then
				for i, line in ipairs(middle_lines) do
					local len = #line
					local y = line_start - last_y + i
					local x = 0

					if x >= 0 and y >= 0 then
						table.insert(integers, y)
						table.insert(integers, x)
						table.insert(integers, len)
						table.insert(integers, tokenTypeMap[type])
						table.insert(integers, modifier_result)
						last_y = last_y + 1
						last_x = 0
					end
				end
			end
		end

		for i, token in ipairs(data.tokens) do
			if token:HasWhitespace() then
				for _, token in ipairs(token:GetWhitespace()) do
					process_token(token)
				end
			end

			local prev = data.tokens[i - 1]
			local types = token:FindType()

			if
				token.type == "string" and
				(
					(
						data.tokens[i - 1].sub_type == "loadstring" or
						data.tokens[i - 2].sub_type == "loadstring"
					)
					or
					(
						data.tokens[i - 1].sub_type == "cdef" or
						data.tokens[i - 2].sub_type == "cdef"
					)
					or
					types[1] and
					types[1].Type == "string" and
					types[1].lua_compiler or
					is_lua(token:GetValueString())
				)
			then
				local func_kind = data.tokens[i - 1]:GetValueString() or data.tokens[i - 2]:GetValueString()
				local str, start = token:DecomposeString()
				local tokens
				local offset = token.start + #start - 1

				if types[1] and types[1].c_tokens then
					tokens = types[1].c_tokens
					local new_tokens = {}

					for i, token in ipairs(tokens) do
						if token:ValueEquals("TYPEOF_CDECL") then
							local offset = tokens[i + 2].stop

							for i = i + 3, #tokens - 3 do
								local token = tokens[i]
								token.start = token.start - offset
								token.stop = token.stop - offset
								table.insert(new_tokens, token)
							end

							break
						end
					end

					if new_tokens[1] then tokens = new_tokens end
				elseif types[1] and types[1].lua_compiler then
					tokens = types[1].lua_compiler.Tokens
				elseif is_probably_lua(str) then
					local compiler = Compiler(str, "temp")
					compiler.OnDiagnostic = function() end
					local ok, err = compiler:Lex()

					if ok then tokens = compiler.Tokens end
				end

				if tokens then
					process_token(Token.NewVirtualToken("fake", start, token.start, token.start + #start))

					for i, token in ipairs(tokens) do
						token.start = token.start + offset
						token.stop = token.stop + offset

						if token:HasWhitespace() then
							for _, token in ipairs(token:GetWhitespace()) do
								process_token(token)
							end
						end

						process_token(token)
					end

					process_token(Token.NewVirtualToken("fake", start, token.stop, token.stop + #start))
				else
					process_token(token)
				end
			else
				process_token(token)
			end
		end

		return integers
	end
end

return META
