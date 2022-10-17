--DONT_ANALYZE
local Compiler = require("nattlua.compiler").New
local helpers = require("nattlua.other.helpers")
local Union = require("nattlua.types.union").Union
local Table = require("nattlua.types.table").Table
local runtime_syntax = require("nattlua.syntax.runtime")
local typesystem_syntax = require("nattlua.syntax.typesystem")
local class = require("nattlua.other.class")
local BuildBaseEnvironment = require("nattlua.runtime.base_environment").BuildBaseEnvironment
local runtime_env, typesystem_env = BuildBaseEnvironment()
local META = class.CreateTemplate("token")
META:GetSet("WorkingDirectory", ".")

META:GetSet("ConfigFunction", function()
	return
end)

function META.New()
	local self = {}
	setmetatable(self, META)
	return self
end

local DiagnosticSeverity = {
	error = 1,
	fatal = 1, -- from lexer and parser
	warning = 2,
	information = 3,
	hint = 4,
}

local function find_type_from_token(token)
	local found_parents = {}

	do
		local node = token.parent

		while node and node.parent do
			table.insert(found_parents, node)
			node = node.parent
		end
	end

	local scope

	for _, node in ipairs(found_parents) do
		if node.scope then
			scope = node.scope

			break
		end
	end

	local union = Union({})

	for _, node in ipairs(found_parents) do
		local found = false

		for _, obj in ipairs(node:GetTypes()) do
			if type(obj) ~= "table" then
				print("UH OH", obj, node, "BAD VALUE IN GET TYPES")
			else
				if obj.Type == "string" and obj:GetData() == token.value then

				else
					if obj.Type == "table" then obj = obj:GetMutatedFromScope(scope) end

					union:AddType(obj)
					found = true
				end
			end
		end

		if found then break end
	end

	if union:IsEmpty() then return nil, found_parents, scope end

	if union:GetLength() == 1 then
		return union:GetData()[1], found_parents, scope
	end

	return union, found_parents, scope
end

local function token_to_type_mod(token)
	if token.type == "symbol" and token.parent.kind == "function_signature" then
		return {[token] = {"keyword"}}
	end

	if
		runtime_syntax:IsNonStandardKeyword(token) or
		typesystem_syntax:IsNonStandardKeyword(token)
	then
		-- check if it's used in a statement, because foo.type should not highlight
		if token.parent and token.parent.type == "statement" then
			return {[token] = {"keyword"}}
		end
	end

	if runtime_syntax:IsKeywordValue(token) or typesystem_syntax:IsKeywordValue(token) then
		return {[token] = {"type"}}
	end

	if
		token.value == "." or
		token.value == ":" or
		token.value == "=" or
		token.value == "or" or
		token.value == "and" or
		token.value == "not"
	then
		return {[token] = {"operator"}}
	end

	if runtime_syntax:IsKeyword(token) or typesystem_syntax:IsKeyword(token) then
		return {[token] = {"keyword"}}
	end

	if
		runtime_syntax:GetTokenType(token):find("operator") or
		typesystem_syntax:GetTokenType(token):find("operator")
	then
		return {[token] = {"operator"}}
	end

	if token.type == "symbol" then return {[token] = {"keyword"}} end

	do
		local obj = find_type_from_token(token)

		if obj then
			local mods = {}

			if obj:IsLiteral() then table.insert(mods, "readonly") end

			if obj.Type == "union" then
				if obj:IsTypeExceptNil("number") then
					return {[token] = {"number", mods}}
				elseif obj:IsTypeExceptNil("string") then
					return {[token] = {"string", mods}}
				elseif obj:IsTypeExceptNil("symbol") then
					return {[token] = {"enumMember", mods}}
				end

				return {[token] = {"event"}}
			end

			if obj.Type == "number" then
				return {[token] = {"number", mods}}
			elseif obj.Type == "string" then
				return {[token] = {"string", mods}}
			elseif obj.Type == "tuple" or obj.Type == "symbol" then
				return {[token] = {"enumMember", mods}}
			elseif obj.Type == "any" then
				return {[token] = {"regexp", mods}}
			end

			if obj.Type == "function" then return {[token] = {"function", mods}} end

			local parent = obj:GetParent()

			if parent then
				if obj.Type == "function" then
					return {[token] = {"macro", mods}}
				else
					if obj.Type == "table" then return {[token] = {"class", mods}} end

					return {[token] = {"property", mods}}
				end
			end

			if obj.Type == "table" then return {[token] = {"class", mods}} end
		end
	end

	if token.type == "number" then
		return {[token] = {"number"}}
	elseif token.type == "string" then
		return {[token] = {"string"}}
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
		if token.value:sub(1, 1) == "@" then return {[token] = {"decorator"}} end
	end

	if token.type == "letter" and token.parent.kind:find("function", nil, true) then
		return {[token] = {"function"}}
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
		return {[token] = {"property"}}
	end

	if token.parent.kind == "table_key_value" then
		return {[token] = {"property"}}
	end

	if token.parent.standalone_letter then
		if token.parent.environment == "typesystem" then
			return {[token] = {"type"}}
		end

		if _G[token.value] then return {[token] = {"namespace"}} end

		return {[token] = {"variable"}}
	end

	if token.parent.is_identifier then
		if token.parent.environment == "typesystem" then
			return {[token] = {"typeParameter"}}
		end

		return {[token] = {"variable"}}
	end

	do
		return {[token] = {"comment"}}
	end
end

local function get_range(code, start, stop)
	local data = helpers.SubPositionToLinePosition(code:GetString(), start, stop)
	return {
		start = {
			line = data.line_start - 1,
			character = data.character_start - 1,
		},
		["end"] = {
			line = data.line_stop - 1,
			character = data.character_stop, -- not sure about this
		},
	}
end

local function find_token_from_line_character(
	tokens--[[#: {[number] = Token}]],
	code--[[#: string]],
	line--[[#: number]],
	char--[[#: number]]
)
	local sub_pos = helpers.LinePositionToSubPosition(code, line, char)

	for _, token in ipairs(tokens) do
		if sub_pos >= token.start and sub_pos <= token.stop then
			return token, helpers.SubPositionToLinePosition(code, token.start, token.stop)
		end
	end
end

function META:GetAanalyzerConfig()
	local cfg = self.ConfigFunction("get-analyzer-config") or {}

	if cfg.type_annotations == nil then cfg.type_annotations = true end

	return cfg
end

function META:GetEmitterConfig()
	local cfg = {
		preserve_whitespace = false,
		string_quote = "\"",
		no_semicolon = true,
		comment_type_annotations = true,
		type_annotations = "explicit",
		force_parenthesis = true,
		skip_import = true,
	}
	local cfg = self.ConfigFunction("get-emitter-config") or cfg
	return cfg
end

local cache = {}
local temp_files = {}

local function find_file(uri)
	if not cache[uri] then
		print("no such file loaded ", uri)

		for k, v in pairs(cache) do
			print(k)
		end
	end

	return cache[uri]
end

local function store_file(uri, code, tokens)
	cache[uri] = {
		code = code,
		tokens = tokens,
	}
end

local function find_temp_file(uri)
	return temp_files[uri]
end

local function store_temp_file(uri, content)
	temp_files[uri] = content
end

local function clear_temp_file(uri)
	temp_files[uri] = nil
end

function META:Recompile(uri)
	local responses = {}
	local compiler
	local entry_point
	local cfg

	if self.WorkingDirectory then
		cfg = self:GetAanalyzerConfig()
		entry_point = cfg.entry_point

		if not entry_point and uri then
			entry_point = uri:gsub(self.WorkingDirectory .. "/", "")
		end

		if not entry_point then return false end

		cfg.inline_require = false
		cfg.on_read_file = function(parser, path)
			responses[path] = responses[path] or
				{
					method = "textDocument/publishDiagnostics",
					params = {uri = self.WorkingDirectory .. "/" .. path, diagnostics = {}},
				}
			return find_temp_file(self.WorkingDirectory .. "/" .. path)
		end
		compiler = Compiler([[return import("./]] .. entry_point .. [[")]], entry_point, cfg)
	else
		compiler = Compiler(find_temp_file(uri), uri)
		responses[uri] = responses[uri] or
			{
				method = "textDocument/publishDiagnostics",
				params = {uri = uri, diagnostics = {}},
			}
	end

	compiler.debug = true
	compiler:SetEnvironments(runtime_env, typesystem_env)

	do
		function compiler:OnDiagnostic(code, msg, severity, start, stop, node, ...)
			local range = get_range(code, start, stop)

			if not range then return end

			local name = code:GetName()
			print("error: ", name, msg, severity, ...)
			responses[name] = responses[name] or
				{
					method = "textDocument/publishDiagnostics",
					params = {uri = self.WorkingDirectory .. "/" .. name, diagnostics = {}},
				}
			table.insert(
				responses[name].params.diagnostics,
				{
					severity = DiagnosticSeverity[severity],
					range = range,
					message = helpers.FormatMessage(msg, ...),
				}
			)
		end

		if compiler:Parse() then
			if compiler.SyntaxTree.imports then
				for _, root_node in ipairs(compiler.SyntaxTree.imports) do
					local root = root_node.RootStatement

					if root_node.RootStatement then
						if not root_node.RootStatement.parser then
							root = root_node.RootStatement.RootStatement
						end

						store_file(
							self.WorkingDirectory .. "/" .. root.parser.config.file_path,
							root.code,
							root.lexer_tokens
						)
					end
				end
			else
				store_file(uri, compiler.Code, compiler.Tokens)
			end

			local should_analyze = true

			if cfg then
				if entry_point then
					local code = self:ReadFile((cfg.working_directory or "") .. entry_point)
					should_analyze = code:find("-" .. "-ANALYZE", nil, true)
				end

				if not should_analyze and uri and uri:find("%.nlua$") then
					should_analyze = true
				end
			end

			if should_analyze then
				local ok, err = compiler:Analyze()

				if not ok then
					local name = compiler:GetCode():GetName()
					responses[name] = responses[name] or
						{
							method = "textDocument/publishDiagnostics",
							params = {uri = self.WorkingDirectory .. "/" .. name, diagnostics = {}},
						}
					table.insert(
						responses[name].params.diagnostics,
						{
							severity = DiagnosticSeverity["fatal"],
							range = get_range(compiler:GetCode(), 1, compiler:GetCode():GetByteSize()),
							message = err,
						}
					)
				end
			end

			self:OnRefresh()
		end

		for _, resp in pairs(responses) do
			self:OnResponse(resp)
		end
	end

	return true
end

function META:ReadFile(path)
	local f = assert(io.open(path, "r"))
	local str = f:read("*all")
	f:close()
	return str
end

function META:OnResponse(response) end

function META:OnRefresh() end

function META:Initialize()
	self:Recompile()
end

function META:Format(code, path)
	local config = self:GetEmitterConfig()
	config.comment_type_annotations = path:sub(-#".lua") == ".lua"
	config.transpile_extensions = path:sub(-#".lua") == ".lua"
	local compiler = Compiler(code, "@" .. path, config)
	local code, err = compiler:Emit()
	return code
end

do -- semantic tokens
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

	function META:DescribeTokens(path)
		local data = find_file(path)

		if not data then return end

		local integers = {}
		local last_y = 0
		local last_x = 0
		local mods = {}

		for _, token in ipairs(data.tokens) do
			if token.type ~= "end_of_file" and token.parent then
				local modified_tokens = token_to_type_mod(token)

				if modified_tokens then
					for token, flags in pairs(modified_tokens) do
						mods[token] = flags
					end
				end
			end
		end

		for _, token in ipairs(data.tokens) do
			if mods[token] then
				local type, modifiers = unpack(mods[token])
				local data = helpers.SubPositionToLinePosition(data.code:GetString(), token.start, token.stop)
				local len = #token.value
				local y = (data.line_start - 1) - last_y
				local x = (data.character_start - 1) - last_x

				-- x is not relative when there's a new line
				if y ~= 0 then x = data.character_start - 1 end

				if type and x >= 0 and y >= 0 then
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

		return integers
	end
end

function META:OpenFile(path, code)
	store_temp_file(path, code)
	self:Recompile(path)
end

function META:CloseFile(path)
	clear_temp_file(path)
end

function META:UpdateFile(path, code)
	store_temp_file(path, code)
	self:Recompile(path)
end

function META:SaveFile(path)
	clear_temp_file(path)
	self:Recompile(path)
end

local function find_token(uri, line, character)
	local data = find_file(uri)

	if not data then
		print("unable to find token", uri, line, character)
		return
	end

	local token, data = find_token_from_line_character(data.tokens, data.code:GetString(), line + 1, character + 1)
	return token, data
end

local function find_token_from_line_character_range(
	uri--[[#: string]],
	lineStart--[[#: number]],
	charStart--[[#: number]],
	lineStop--[[#: number]],
	charStop--[[#: number]]
)
	local data = find_file(uri)

	if not data then
		print(
			"unable to find requested token range",
			uri,
			lineStart,
			charStart,
			lineStop,
			charStop
		)
		return
	end

	local sub_pos_start = helpers.LinePositionToSubPosition(data.code, lineStart, charStart)
	local sub_pos_stop = helpers.LinePositionToSubPosition(data.code, lineStop, charStop)
	local found = {}

	for _, token in ipairs(tokens) do
		if token.start >= sub_pos_start and token.stop <= sub_pos_stop then
			table.insert(found, token)
		end
	end

	return found
end

local function has_value(tbl, str)
	for _, v in ipairs(tbl) do
		if v == str then return true end
	end

	return false
end

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
	local tokens = find_token_from_line_character_range(
		path,
		start_line - 1,
		start_character - 1,
		stop_line - 1,
		stop_character - 1
	)

	if not tokens then return end

	local hints = {}
	local assignments = find_nodes(tokens, "statement", "local_assignment")

	for _, assingment in ipairs(find_nodes(tokens, "statement", "assignment")) do
		table.insert(assignments, assingment)
	end

	for _, assignment in ipairs(assignments) do
		if assignment.environment == "runtime" then
			for i, left in ipairs(assignment.left) do
				if not left.tokens[":"] and assignment.right and assignment.right[i] then
					local types = left:GetTypes()

					if
						types and
						(
							assignment.right[i].kind ~= "value" or
							assignment.right[i].value.value.type == "letter"
						)
					then
						local data = helpers.SubPositionToLinePosition(compiler.Code:GetString(), left:GetStartStop())
						local label = tostring(Union(types))

						if #label > 20 then label = label:sub(1, 20) .. "..." end

						table.insert(
							hints,
							{
								label = ": " .. label,
								tooltip = tostring(Union(types)),
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

function META:Rename(path, line, character, newName)
	local token, data = find_token(path, line, character)

	if not token or not data or not token.parent then return end

	local obj = find_type_from_token(token)
	local upvalue = obj:GetUpvalue()
	local changes = {}

	if upvalue and upvalue.mutations then
		for i, v in ipairs(upvalue.mutations) do
			local node = v.value:GetNode()

			if node then
				changes[path] = changes[path] or
					{
						textDocument = {
							version = nil,
						},
						edits = {},
					}
				local edits = changes[path].edits
				table.insert(
					edits,
					{
						range = get_range(node.Code, node:GetStartStop()),
						newText = newName,
					}
				)
			end
		end
	end

	return {
		changes = changes,
	}
end

function META:GetDefinition(path, line, character)
	local token, data = find_token(path, line, character)

	if not token or not data or not token.parent then return end

	local obj = find_type_from_token(token)

	if not obj or not obj:GetUpvalue() then return end

	local node = obj:GetUpvalue():GetNode()

	if not node then return end

	local data = find_file(path)
	return {
		uri = path,
		range = get_range(data.code, node:GetStartStop()),
	}
end

function META:GetHover(path, line, character)
	local token, data = find_token(path, line, character)

	if not token or not data or not token.parent then return end

	local obj, found_parents, scope = find_type_from_token(token)
	return {
		obj = obj,
		scope = scope,
		found_parents = found_parents,
	}
end

return META