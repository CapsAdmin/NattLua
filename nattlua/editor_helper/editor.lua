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
	local self = {
		TempFiles = {},
		LoadedFiles = {},
	}
	setmetatable(self, META)
	return self
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

function META:GetFile(path)
	if not self.LoadedFiles[path] then
		print("no such file loaded ", path)

		for k, v in pairs(cache) do
			print(k)
		end
	end

	return self.LoadedFiles[path]
end

function META:GetTempFile(path)
	return self.TempFiles[path]
end

function META:StoreFile(path, code, tokens)
	self.LoadedFiles[path] = {
		code = code,
		tokens = tokens,
	}
end

function META:StoreTempFile(path, code)
	self.TempFiles[path] = code
end

function META:ClearTempFile(path)
	self.TempFiles[path] = nil
end

function META:Recompile(uri)
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
			return self:GetTempFile(self.WorkingDirectory .. "/" .. path)
		end
		compiler = Compiler([[return import("./]] .. entry_point .. [[")]], entry_point, cfg)
	else
		compiler = Compiler(self:GetTempFile(uri), uri)
	end

	compiler.debug = true
	compiler:SetEnvironments(runtime_env, typesystem_env)
	local diagnostics = {}

	do
		function compiler.OnDiagnostic(_, code, msg, severity, start, stop, node, ...)
			local name = code:GetName()
			diagnostics[name] = diagnostics[name] or {}
			table.insert(
				diagnostics[name],
				{
					severity = severity,
					code = code,
					start = start,
					stop = stop,
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

						self:StoreFile(
							self.WorkingDirectory .. "/" .. root.parser.config.file_path,
							root.code,
							root.lexer_tokens
						)
					end
				end
			else
				self:StoreFile(uri, compiler.Code, compiler.Tokens)
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
			end
		end
	end

	for name, data in pairs(diagnostics) do
		self:OnDiagnostics(name, data)
	end
end

function META:OnDiagnostics(name, data) end

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
		local data = self:GetFile(path)

		if not data then return end

		local integers = {}
		local last_y = 0
		local last_x = 0
		local mods = {}

		for _, token in ipairs(data.tokens) do
			if token.type ~= "end_of_file" and token.parent then
				local type, modss = token:GetTypeMod()

				if type then mods[token] = {type, modss} end
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
	self:StoreTempFile(path, code)
	self:Recompile(path)
end

function META:CloseFile(path)
	self:ClearTempFile(path)
end

function META:UpdateFile(path, code)
	self:StoreTempFile(path, code)
	self:Recompile(path)
end

function META:SaveFile(path)
	self:ClearTempFile(path)
	self:Recompile(path)
end

function META:FindToken(path, line, char)
	local data = self:GetFile(path)

	if not data then
		print("unable to find token", path, line, character)
		return
	end

	local sub_pos = helpers.LinePositionToSubPosition(data.code:GetString(), line + 1, char + 1)

	for _, token in ipairs(data.tokens) do
		if sub_pos >= token.start and sub_pos <= token.stop then
			return token, data
		end
	end

	return nil
end

function META:FindTokensFromRange(
	path--[[#: string]],
	line_start--[[#: number]],
	char_start--[[#: number]],
	line_stop--[[#: number]],
	char_stop--[[#: number]]
)
	local data = self:GetFile(path)

	if not data then
		print(
			"unable to find requested token range",
			path,
			line_start,
			char_start,
			line_stop,
			char_stop
		)
		return
	end

	local sub_pos_start = helpers.LinePositionToSubPosition(data.code, line_start, char_start)
	local sub_pos_stop = helpers.LinePositionToSubPosition(data.code, line_stop, char_stop)
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
	local tokens = self:FindTokensFromRange(
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
					local types = left:GetAssociatedTypes()

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

function META:GetCode(path)
	local data = self:GetFile(path)
	return data.code
end

function META:GetRenameInstructions(path, line, character, newName)
	local token, data = self:FindToken(path, line, character)
	assert(token.type == "letter", "cannot rename non letter " .. token.value)

	if not token then return end

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

	if not token or not data or not token.parent then return end

	local obj = token:FindType()[1]

	if not obj or not obj:GetUpvalue() then return end

	local node = obj:GetUpvalue():GetNode()

	if not node then return end

	local data = self:GetFile(path)
	return {
		uri = path,
		range = get_range(data.code, node:GetStartStop()),
	}
end

function META:GetHover(path, line, character)
	local token, data = self:FindToken(path, line, character)

	if not token or not data or not token.parent then return end

	local types, found_parents, scope = token:FindType()
	return {
		obj = Union(types),
		scope = scope,
		found_parents = found_parents,
	}
end

return META