local Compiler = require("nattlua.compiler").New
local helpers = require("nattlua.other.helpers")
local b64 = require("nattlua.other.base64")
local Union = require("nattlua.types.union").Union
local lsp = {}
lsp.methods = {}
local TextDocumentSyncKind = {None = 0, Full = 1, Incremental = 2}
local DiagnosticSeverity = {
	error = 1,
	fatal = 1, -- from lexer and parser
	warning = 2,
	information = 3,
	hint = 4,
}
local SymbolKind = {
	File = 1,
	Module = 2,
	Namespace = 3,
	Package = 4,
	Class = 5,
	Method = 6,
	Property = 7,
	Field = 8,
	Constructor = 9,
	Enum = 10,
	Interface = 11,
	Function = 12,
	Variable = 13,
	Constant = 14,
	String = 15,
	Number = 16,
	Boolean = 17,
	Array = 18,
	Object = 19,
	Key = 20,
	Null = 21,
	EnumMember = 22,
	Struct = 23,
	Event = 24,
	Operator = 25,
	TypeParameter = 26,
}
local SemanticTokenTypes = {
	"namespace",
	"type",
	"class",
	"enum",
	"interface",
	"struct",
	"typeParameter",
	"parameter",
	"variable",
	"property",
	"enumMember",
	"event",
	"function",
	"method",
	"macro",
	"keyword",
	"modifier",
	"comment",
	"string",
	"number",
	"regexp",
	"operator",
}
local SemanticTokenModifiers = {
	"declaration",
	"definition",
	"readonly",
	"static",
	"deprecated",
	"abstract",
	"async",
	"modification",
	"documentation",
	"defaultLibrary",
}
local working_directory

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

local function find_token_from_line_character_range(
	tokens--[[#: {[number] = Token}]],
	code--[[#: string]],
	lineStart--[[#: number]],
	charStart--[[#: number]],
	lineStop--[[#: number]],
	charStop--[[#: number]]
)
	local sub_pos_start = helpers.LinePositionToSubPosition(code, lineStart, charStart)
	local sub_pos_stop = helpers.LinePositionToSubPosition(code, lineStop, charStop)
	local found = {}

	for _, token in ipairs(tokens) do
		if token.start >= sub_pos_start and token.stop <= sub_pos_stop then
			table.insert(found, token)
		end
	end

	return found
end

local function get_analyzer_config()
	--[[#£ parser.dont_hoist_next_import = true]]

	local f, err = loadfile("./nlconfig.lua")
	local cfg = {}

	if f then cfg = f("get-analyzer-config") or cfg end

	if cfg.type_annotations == nil then cfg.type_annotations = true end

	return cfg
end

local function get_emitter_config()
	--[[#£ parser.dont_hoist_next_import = true]]

	local f, err = loadfile("./nlconfig.lua")
	local cfg = {
		preserve_whitespace = false,
		string_quote = "\"",
		no_semicolon = true,
		comment_type_annotations = true,
		type_annotations = "explicit",
		force_parenthesis = true,
		skip_import = true,
	}

	if f then cfg = f("get-emitter-config") or cfg end

	return cfg
end

local BuildBaseEnvironment = require("nattlua.runtime.base_environment").BuildBaseEnvironment
local runtime_env, typesystem_env = BuildBaseEnvironment()
local cache = {}
local temp_files = {}

local function find_file(uri)
	return cache[uri]
end

local function find_temp_file(uri)
	return temp_files[uri]
end

local function store_temp_file(uri, content)
	print("storing ", uri, #content)
	temp_files[uri] = content
end

local function clear_temp_file(uri)
	print("clearing ", uri)
	temp_files[uri] = nil
end

local function recompile()
	local cfg = get_analyzer_config()

	if not cfg.entry_point then return false end

	print("RECOMPILE")
	local responses = {}
	cfg.inline_require = false
	cfg.on_read_file = function(parser, path)
		responses[path] = responses[path] or
			{
				method = "textDocument/publishDiagnostics",
				params = {uri = working_directory .. "/" .. path, diagnostics = {}},
			}
		return find_temp_file(working_directory .. "/" .. path)
	end
	local compiler = Compiler(
		[[return import("./]] .. cfg.entry_point .. [[")]],
		tostring("file://" .. cfg.entry_point),
		cfg
	)
	compiler:SetEnvironments(runtime_env, typesystem_env)

	do
		function compiler:OnDiagnostic(code, msg, severity, start, stop, node, ...)
			local range = get_range(code, start, stop)

			if not range then return end

			local name = code:GetName()
			responses[name] = responses[name] or
				{
					method = "textDocument/publishDiagnostics",
					params = {uri = working_directory .. "/" .. name, diagnostics = {}},
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
			for _, root_node in ipairs(compiler.SyntaxTree.imports) do
				local root = root_node.RootStatement

				if not root_node.RootStatement.parser then
					root = root_node.RootStatement.RootStatement
				end

				cache[working_directory .. "/" .. root.parser.config.file_path] = {tokens = root.lexer_tokens, code = root.code}
			end

			compiler:Analyze()
		end

		for _, resp in pairs(responses) do
			lsp.Call(resp)
		end
	end

	lsp.Call({method = "workspace/semanticTokens/refresh"})
	return true
end

lsp.methods["initialize"] = function(params)
	working_directory = params.workspaceFolders[1].uri
	return {
		clientInfo = {name = "NattLua", version = "1.0"},
		capabilities = {
			textDocumentSync = {
				openClose = true,
				change = TextDocumentSyncKind.Full,
			},
			hoverProvider = true,
			publishDiagnostics = {
				relatedInformation = true,
				tagSupport = {1, 2},
			},
			semanticTokens = {
				range = true,
				legend = {
					tokenTypes = SemanticTokenTypes,
					tokenModifiers = SemanticTokenModifiers,
				},
			},
		-- for symbols like all functions within a file
		-- documentSymbolProvider = {label = "NattLua"},
		-- highlighting equal upvalues
		-- documentHighlightProvider = true, 
		--[[completionProvider = {
				resolveProvider = true,
				triggerCharacters = { ".", ":" },
			},
			signatureHelpProvider = {
				triggerCharacters = { "(" },
			},
			definitionProvider = true,
			referencesProvider = true,
			
			workspaceSymbolProvider = true,
			codeActionProvider = true,
			codeLensProvider = {
				resolveProvider = true,
			},
			documentFormattingProvider = true,
			documentRangeFormattingProvider = true,
			documentOnTypeFormattingProvider = {
				firstTriggerCharacter = "}",
				moreTriggerCharacter = { "end" },
			},
			renameProvider = true,
			]] },
	}
end
lsp.methods["initialized"] = function(params)
	recompile()
end
lsp.methods["nattlua/format"] = function(params)
	print("FORMAT")
	table.print(params)
	local config = get_emitter_config()
	config.comment_type_annotations = params.path:sub(-#".lua") == ".lua"
	local compiler = Compiler(params.code, "@" .. params.path, config)
	local code, err = compiler:Emit()
	return {code = b64.encode(code)}
end
lsp.methods["shutdown"] = function(params)
	print("SHUTDOWN")
	table.print(params)
end

do -- semantic tokens
	local tokenTypeMap = {}
	local tokenModifiersMap = {}

	for i, v in ipairs(SemanticTokenTypes) do
		tokenTypeMap[v] = i - 1
	end

	for i, v in ipairs(SemanticTokenModifiers) do
		tokenModifiersMap[v] = i - 1
	end

	local function token_to_type_mod(token)
		if token.parent and token.parent.kind == "local_assignment" then
			return "declaration"
		end

		if token.type == "number" then
			return "number"
		elseif token.type == "string" then
			return "string"
		end
	end

	lsp.methods["textDocument/semanticTokens/range"] = function(params)
		do
			return
		end

		local textDocument = params.textDocument
		local range = params
	end
	lsp.methods["textDocument/semanticTokens/full"] = function(params)
		do
			return
		end

		local compiler = compile(params.textDocument.uri, params.textDocument.text)
		local integers = {}
		local last_y = 0
		local last_x = 0

		for _, token in ipairs(compiler.Tokens) do
			local data = helpers.SubPositionToLinePosition(compiler.Code:GetString(), token.start, token.stop)

			if data then
				local len = #token.value
				local y = (data.line_start - 1) - last_y
				local x = data.character_start - last_x

				if y ~= 0 then x = data.character_start end

				local type, modifiers = token_to_type_mod(token)

				if type then
					table.insert(integers, y)
					table.insert(integers, x)
					table.insert(integers, len)
					table.insert(integers, tokenTypeMap[type])
					local result = 0

					if modifiers then
						for _, mod in ipairs(modifiers) do
							assert(tokenModifiersMap[mod], "invalid modifier " .. mod)
							result = bit.bor(result, bit.lshift(1, tokenModifiersMap[mod]))
						end
					end

					table.insert(integers, result)
					last_y = (data.line_start - 1)
					last_x = data.character_start
				end
			end
		end

		return {data = integers}
	end
end

lsp.methods["$/cancelRequest"] = function(params)
	do
		return
	end

	print("cancelRequest")
	table.print(params)
end
lsp.methods["workspace/didChangeConfiguration"] = function(params)
	print("configuration changed")
	table.print(params)
end
lsp.methods["textDocument/didOpen"] = function(params)
	do
		return
	end

	store_temp_file(params.textDocument.uri, params.contentChanges[1].text)
	recompile()
end
lsp.methods["textDocument/didClose"] = function(params)
	do
		return
	end

	clear_temp_file(params.textDocument.uri)
end
lsp.methods["textDocument/didChange"] = function(params)
	store_temp_file(params.textDocument.uri, params.contentChanges[1].text)
	recompile()
end
lsp.methods["textDocument/didSave"] = function(params)
	do
		return
	end

	clear_temp_file(params.textDocument.uri)
	recompile()
end

local function find_token(uri, text, line, character)
	local data = find_file(uri)

	if not data then return end

	local token, data = find_token_from_line_character(data.tokens, data.code:GetString(), line + 1, character + 1)
	return token, data
end

local function find_type_from_token(token)
	local found_parents = {}

	do
		local node = token.parent

		while node.parent do
			table.insert(found_parents, node)
			node = node.parent
		end
	end

	for _, node in ipairs(found_parents) do
		for _, obj in ipairs(node:GetTypes()) do
			if obj.Type == "string" and obj:GetData() == token.value then

			else
				return obj, found_parents, node
			end
		end
	end

	return nil, found_parents
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

lsp.methods["textDocument/inlay"] = function(params)
	do
		return
	end

	local compiler = compile(params.textDocument.uri, params.textDocument.text)
	local tokens = find_token_from_line_character_range(
		compiler.Tokens,
		compiler.Code:GetString(),
		params.start.line - 1,
		params.start.character - 1,
		params["end"].line - 1,
		params["end"].character - 1
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

	return {
		hints = hints,
	}
end
lsp.methods["textDocument/rename"] = function(params)
	do
		return
	end

	local token, data = find_token(
		params.textDocument.uri,
		params.textDocument.text,
		params.position.line,
		params.position.character
	)

	if not token or not data or not token.parent then return end

	local obj = find_type_from_token(token)
	local upvalue = obj:GetUpvalue()
	local changes = {}

	if upvalue and upvalue.mutations then
		for i, v in ipairs(upvalue.mutations) do
			local node = v.value:GetNode()

			if node then
				changes[params.textDocument.uri] = changes[params.textDocument.uri] or
					{
						textDocument = {
							version = nil,
						},
						edits = {},
					}
				local edits = changes[params.textDocument.uri].edits
				table.insert(
					edits,
					{
						range = get_range(node.Code, node:GetStartStop()),
						newText = params.newName,
					}
				)
			end
		end
	end

	return {
		changes = changes,
	}
end
lsp.methods["textDocument/hover"] = function(params)
	local token, data = find_token(
		params.textDocument.uri,
		params.textDocument.text,
		params.position.line,
		params.position.character
	)

	if not token or not data or not token.parent then return end

	local markdown = ""

	local function add_line(str)
		markdown = markdown .. str .. "\n\n"
	end

	local function add_code(str)
		add_line("```lua\n" .. tostring(str) .. "\n```")
	end

	local obj, found_parents = find_type_from_token(token)

	if obj then add_code(tostring(obj)) end

	if found_parents[2] then
		local min, max = found_parents[2]:GetStartStop()

		if min then
			local temp = helpers.SubPositionToLinePosition(found_parents[2].Code:GetString(), min, max)

			if temp then data = temp end
		end
	end

	return {
		contents = markdown,
		range = {
			start = {
				line = data.line_start - 1,
				character = data.character_start - 1,
			},
			["end"] = {
				line = data.line_stop - 1,
				character = data.character_stop,
			},
		},
	}
end

do
	local MessageType = {error = 1, warning = 2, info = 3, log = 4}

	function lsp.ShowMessage(type, msg)
		lsp.Call(
			{
				method = "window/showMessage",
				params = {
					type = assert(MessageType[type]),
					message = msg,
				},
			}
		)
	end

	function lsp.LogMessage(type, msg)
		lsp.Call(
			{
				method = "window/logMessage",
				params = {
					type = assert(MessageType[type]),
					message = msg,
				},
			}
		)
	end
end

function lsp.Call(params)
	if lsp.methods[params.method] then lsp.methods[params.method](params) end
end

return lsp