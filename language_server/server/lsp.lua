local nl = require("nattlua")
local helpers = require("nattlua.other.helpers")
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

local function get_range(code, start, stop)
	local data = helpers.SubPositionToLinePosition(code:GetString(), start, stop)

	if data.line_start == 0 or data.line_stop == 0 then
		print("invalid position")
		print(start, stop)
		table.print(data)
		return
	end

	return {
		start = {
			line = data.line_start - 1,
			character = data.character_start,
		},
		["end"] = {
			line = data.line_stop - 1,
			character = data.character_stop,
		},
	}
end

local cache = {}

local function compile(self, uri, lua_code)
	lua_code = lua_code or cache[uri] and cache[uri].Code:GetString()

	if cache[uri] and lua_code ~= cache[uri].Code:GetString() then
		cache[uri] = nil
	end

	if cache[uri] then return cache[uri] end

	local compiler = nl.Compiler(lua_code, uri, {type_annotations = true})

	do
		local resp = {
			method = "textDocument/publishDiagnostics",
			params = {uri = uri, diagnostics = {}},
		}

		function compiler:OnDiagnostic(code, msg, severity, start, stop, ...)
			local range = get_range(code, start, stop)

			if not range then return end

			table.insert(
				resp.params.diagnostics,
				{
					severity = DiagnosticSeverity[severity],
					range = range,
					message = helpers.FormatMessage(msg, ...),
				}
			)
		end

		compiler:Lex()
		compiler:Parse()

		if VSCODE_PLUGIN then
			if lua_code:find("--A" .. "NALYZE", nil, true) then compiler:Analyze() end
		else
			compiler:Analyze()
		end

		if #resp.params.diagnostics > 0 then lsp.Call(resp) end
	end

	lsp.Call({method = "workspace/semanticTokens/refresh"})
	cache[uri] = compiler
	return cache[uri]
end

lsp.methods["initialized"] = function(self, params)
	print("vscode ready")
end
lsp.methods["initialize"] = function(self, params)
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
		if syntax.IsKeyword(token) or syntax.IsNonStandardKeyword(token) then
			if token.value == "type" then return "type" end

			return "keyword"
		end

		if token.parent and token.parent.kind == "local_assignment" then
			return "declaration"
		end

		if token.type == "number" then
			return "number"
		elseif token.type == "string" then
			return "string"
		end
	end

	lsp.methods["textDocument/semanticTokens/range"] = function(self, params)
		local textDocument = params.textDocument
		local range = params
	end
	lsp.methods["textDocument/semanticTokens/full"] = function(self, params)
		local compiler = compile(self, params.textDocument.uri, params.textDocument.text)
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

lsp.methods["$/cancelRequest"] = function(self, params)
	print("cancelRequest")
	table.print(params)
end
lsp.methods["workspace/didChangeConfiguration"] = function(self, params)
	print("configuration changed")
	table.print(params)
end
lsp.methods["textDocument/didOpen"] = function(self, params)
	compile(self, params.textDocument.uri, params.textDocument.text)
	print("opened", params.textDocument.uri)
end
lsp.methods["textDocument/didClose"] = function(self, params)
	cache[params.textDocument.uri] = nil
	print("closed", params.textDocument.uri)
end
lsp.methods["textDocument/didChange"] = function(self, params)
	compile(self, params.textDocument.uri, params.contentChanges[1].text)
end
lsp.methods["textDocument/didSave"] = function(self, params)
	compile(self, params.textDocument.uri, params.textDocument.text)
end
lsp.methods["textDocument/hover"] = function(self, params)
	local compiler = compile(self, params.textDocument.uri, params.textDocument.text)
	local pos = params.position
	local token, data = helpers.GetDataFromLineCharPosition(compiler.Tokens, compiler.Code:GetString(), pos.line + 1, pos.character + 1)

	if not token or not data then
		error("cannot find anything at " .. params.textDocument.uri .. ":" .. pos.line .. ":" .. pos.character)
	end

	local found_parents = {}

	do
		local node = token

		while node.parent do
			table.insert(found_parents, node.parent)
			node = node.parent
		end
	end

	local markdown = ""

	local function add_line(str)
		markdown = markdown .. str .. "\n\n"
	end

	local function add_code(str)
		add_line("```lua\n" .. tostring(str) .. "\n```")
	end

	local function get_type(obj)
		local upvalue = obj:GetUpvalue()

		if upvalue then return upvalue:GetValue() end

		return obj
	end

	if token:GetLastType() then
		add_code(get_type(token:GetLastType()))
	else
		for _, node in ipairs(found_parents) do
			if node:GetLastType() then
				add_code(get_type(node:GetLastType()))

				break
			end
		end
	end

	if false then
		add_line("nodes:\n\n")
		add_code("\t[token - " .. token.type .. " (" .. token.value .. ")]")

		for _, node in ipairs(found_parents) do
			add_code("\t" .. tostring(node))
		end
	end

	if token and token.parent then
		local min, max = token.parent:GetStartStop()

		if min then
			local temp = helpers.SubPositionToLinePosition(compiler.Code:GetString(), min, max)

			if temp then data = temp end
		end
	end

	return {
		contents = markdown,
		range = {
			start = {
				line = data.line_start - 1,
				character = data.character_start,
			},
			["end"] = {
				line = data.line_stop - 1,
				character = data.character_stop + 1,
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
