--DONT_ANALYZE
local b64 = require("nattlua.other.base64")
local EditorHelper = require("nattlua.editor_helper.editor")
local helpers = require("nattlua.other.helpers")
local lsp = {}
lsp.methods = {}
local TextDocumentSyncKind = {None = 0, Full = 1, Incremental = 2}
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
local editor_helper = EditorHelper.New()
lsp.methods["initialize"] = function(params)
	editor_helper:SetWorkingDirectory(params.workspaceFolders[1].uri)
	return {
		clientInfo = {name = "NattLua", version = "1.0"},
		capabilities = {
			textDocumentSync = {
				openClose = true,
				change = TextDocumentSyncKind.Full,
			},
			semanticTokensProvider = {
				legend = {
					tokenTypes = SemanticTokenTypes,
					tokenModifiers = SemanticTokenModifiers,
				},
				full = true,
				range = false,
			},
			hoverProvider = true,
			publishDiagnostics = {
				relatedInformation = true,
				tagSupport = {1, 2},
			},
			inlayHintProvider = {
				resolveProvider = true,
			},
			definitionProvider = true,
			renameProvider = true,
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
	editor_helper:Initialize()

	function editor_helper:OnRefresh()
		lsp.Call({method = "workspace/semanticTokens/refresh", params = {}})
	end

	function editor_helper:OnResponse(resp)
		lsp.Call(resp)
	end

	--[[#£ parser.dont_hoist_next_import = true]]

	local f, err = loadfile("./nlconfig.lua")

	if f then editor_helper:SetConfigFunction(f) end
end
lsp.methods["nattlua/format"] = function(params)
	return {code = b64.encode(editor_helper:Format(params.code, params.path))}
end
lsp.methods["nattlua/syntax"] = function(params)
	local data = require("nattlua.syntax.monarch_language")
	print("SENDING SYNTAX", #data)
	return {data = b64.encode(data)}
end
lsp.methods["shutdown"] = function(params)
	print("SHUTDOWN")
	table.print(params)
end
lsp.methods["textDocument/semanticTokens/full"] = function(params)
	local integers = editor_helper:DescribeTokens(params.textDocument.uri)
	return {data = integers}
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
	editor_helper:OpenFile(params.textDocument.uri, params.textDocument.text)
end
lsp.methods["textDocument/didClose"] = function(params)
	editor_helper:CloseFile(params.textDocument.uri)
end
lsp.methods["textDocument/didChange"] = function(params)
	editor_helper:UpdateFile(params.textDocument.uri, params.contentChanges[1].text)
end
lsp.methods["textDocument/didSave"] = function(params)
	editor_helper:SaveFile(params.textDocument.uri)
end
lsp.methods["textDocument/inlayHint"] = function(params)
	local hints = editor_helper:GetInlayHints(
		params.textDocument.uri,
		params.start.line,
		params.start.character,
		params["end"].line,
		params["end"].character
	)
	return hints
end
lsp.methods["textDocument/rename"] = function(params)
	local changes = editor_helper:Rename(params.textDocument.uri, params.position.line, params.position.character, params.newName)
	return {
		changes = changes,
	}
end
lsp.methods["textDocument/definition"] = function(params)
	local data = editor_helper:GetDefinition(params.textDocument.uri, params.position.line, params.position.character)
	return data
end
lsp.methods["textDocument/hover"] = function(params)
	local data = editor_helper:GetHover(params.textDocument.uri, params.position.line, params.position.character)

	if not data then return end

	local markdown = ""

	local function add_line(str)
		markdown = markdown .. str .. "\n\n"
	end

	local function add_code(str)
		add_line("```lua\n" .. tostring(str) .. "\n```")
	end

	if data.obj then
		add_code(tostring(data.obj))
		local upvalue = data.obj:GetUpvalue()

		if upvalue then
			add_code(tostring(upvalue))

			if upvalue:HasMutations() then
				local code = ""

				for i, mutation in ipairs(upvalue.Mutations) do
					code = code .. "-- " .. i .. "\n"
					code = code .. "\tvalue = " .. tostring(mutation.value) .. "\n"
					code = code .. "\tscope = " .. tostring(mutation.scope) .. "\n"
					code = code .. "\ttracking = " .. tostring(mutation.from_tracking) .. "\n"
				end

				add_code(code)
			end
		end
	end

	local wtf = data.found_parents

	if wtf[1] then
		local min, max = wtf[1]:GetStartStop()

		if min then
			local temp = helpers.SubPositionToLinePosition(wtf[1].Code:GetString(), min, max)

			if temp then data = temp end
		end

		for i = 1, #wtf do
			local min, max = wtf[i]:GetStartStop()
			add_code(tostring(wtf[i]) .. " len=" .. tostring(max - min))
		end
	end

	if data.scope then markdown = markdown .. "\n" .. tostring(data.scope) end

	local limit = 5000

	if #markdown > limit then markdown = markdown:sub(0, limit) .. "\n```\n..." end

	markdown = markdown:gsub("\\", "BSLASH_")
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

-- this can be overriden
function lsp.Call(params)
	if lsp.methods[params.method] then lsp.methods[params.method](params) end
end

return lsp