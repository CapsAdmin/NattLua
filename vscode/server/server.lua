io.stdout:setvbuf("no")
io.stderr:setvbuf("no")
io.flush()

local ffi = require("ffi")
local json = require("nattlua.other.json")
local nl = require("nattlua")
local helpers = require("nattlua.other.helpers")
local table_print = require("examples.util").TablePrint
local syntax = require("nattlua.syntax.syntax")
local base_environment = require("nattlua.runtime.base_environment")
local server = require("vscode.server.lsp")

local TextDocumentSyncKind = {
	None = 0,
	Full = 1,
	Incremental = 2,
}

local DiagnosticSeverity = {
	Error = 1,
	Warning = 2,
	Information = 3,
	Hint = 4,
}
local documents = {}
local function compile(uri, server, client)
	local code
	
	if documents[uri] then
		code = documents[uri]
	else
		local f = assert(io.open(uri:sub(#"file://" + 1), "r"))
		code = f:read("*all")
		f:close()
	end

	local compiler = nl.Compiler(code, uri, {annotate = true})

	local resp = {
		method = "textDocument/publishDiagnostics",
		params = {
			uri = uri,
			diagnostics = {},
		}
	}

	function compiler:OnDiagnostic(code, name, msg, severity, start, stop, ...)
        msg = helpers.FormatMessage(msg, ...)
        
        local data = helpers.SubPositionToLinePosition(code, start, stop)
        
		if not data then
			local code = io.open(base_environment.path):read("*all")
			data = helpers.SubPositionToLinePosition(code, start, stop)
			if not data then
				print("INTERNAL ERROR: ", self, msg, start, stop, ...)
				return
			end
		end

		table.insert(resp.params.diagnostics, {
			severity = DiagnosticSeverity[severity],
			range = {
				start = {
					line = data.line_start-1,
					character = data.character_start,
				},
				["end"] = {
					line = data.line_stop-1,
					character = data.character_stop,
				},
			},
			message = msg,
		})

	end

	if uri:find("test_focus") then
		compiler:Analyze()
	end

	server:Respond(client, resp)

	local tokens
	local ast

	if compiler:Lex() then
		tokens = compiler.Tokens
	end

	if compiler:Parse() then
		ast = compiler.SyntaxTree
	end

	return code, tokens, ast
end

local tokenTypeMap = {}
local tokenModifiersMap = {}

server.methods["initialize"] = function(params, self, client) 
	local rootUri = params.rootUri
	local capabilities = params.capabilities
	print(rootUri)
	table_print(capabilities)

	local tokenTypes = {
		"interface",
		"struct",
		
		"typeParameter",
		"parameter",
		"type",
		"variable",
		"property",
		"function",
		"method",
		"keyword",
		"comment",
		"string",
		"number",
		"operator"
	}
	local tokenModifiers = {
		"declaration",
		"readonly",
		"deprecated",
		"private",
		"static"
	}

	for i,v in ipairs(tokenTypes) do
		tokenTypeMap[v] = i - 1
	end

	for i,v in ipairs(tokenModifiers) do
		tokenModifiersMap[v] = i - 1
	end

	return {
		capabilities = {
			textDocumentSync = {
				openClose = true,
				change = TextDocumentSyncKind.Full,
			},
			hoverProvider = true,


			-- tokens
			semanticTokensProvider = {
				legend = {
					tokenTypes = tokenTypes,
					tokenModifiers = tokenModifiers,
				},
				range = false, -- wip
				full = true,
			},
			--[[completionProvider = {
				resolveProvider = true,
				triggerCharacters = { ".", ":" },
			},
			signatureHelpProvider = {
				triggerCharacters = { "(" },
			},
			definitionProvider = true,
			referencesProvider = true,
			documentHighlightProvider = true,
			documentSymbolProvider = true,
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
			publishDiagnostics = {
				relatedInformation = true,
				tags = {1,2},
			},]]
		}
	}
end

server.methods["textDocument/didOpen"] = function(params, self, client)
	local textDocument = params.textDocument
	documents[textDocument.uri] = textDocument.text
end

server.methods["textDocument/didChange"] = function(params, self, client) 
	local textDocument = params.textDocument
	local content = params.contentChanges[1].text
	
	documents[textDocument.uri] = content
end
server.methods["textDocument/didSave"] = function(params, self, client) end

server.methods["textDocument/semanticTokens/range"] = function(params, self, client) 
	local textDocument = params.textDocument
	local range = params

	print(textDocument, range)
end

local function token_to_type_mod(token)
	if syntax.IsKeyword(token) or syntax.IsNonStandardKeyword(token) then
		if token.value == "type" then
			return "type"
		end

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

server.methods["textDocument/semanticTokens/full"] = function(params, self, client) 
	local textDocument = params.textDocument
	
	local code, tokens = compile(textDocument.uri, self, client)
	
	local integers = {}

	local last_y = 0
	local last_x = 0

	for _, token in ipairs(tokens) do
		local data = helpers.SubPositionToLinePosition(code, token.start, token.stop)

		if data then
			local len = #token.value
			local y = (data.line_start - 1) - last_y
			local x = data.character_start - last_x
			
			if y ~= 0 then
				x = data.character_start
			end

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

	return {
		data = integers,
	}
end

server.methods["textDocument/hover"] = function(params, self, client)
	local code, tokens = compile(params.textDocument.uri, self, client)
	local pos = params.position

	local token, data = helpers.GetDataFromLineCharPosition(tokens, code, pos.line + 1, pos.character + 1)
	
	if not token then
		error("cannot find anything at " .. params.textDocument.uri .. ":" .. pos.line .. ":" .. pos.character)
	end

	local found = {}
	local node = token
	repeat
		table.insert(found, node)
		node = node.parent
	until not node

	local str = "```lua\n"

	str = str .. token.value .. "\n"

	for k,v in pairs(token) do
		str = str .. k .. " = " .. tostring(v) .. "\n"
	end

	for i,v in ipairs(found) do
		if v.inferred_type then
			str = str .. "\n```lua\n"
			str = str .. tostring(v.inferred_type)
			str = str .. "\n```\n"
			break
		end
	end

	str = str .. tostring(token.parent) .. "\n"

	if token and token.parent then
		local min, max = helpers.LazyFindStartStop(token.parent)
		if min then
			data = helpers.SubPositionToLinePosition(code, min, max)
		end
	end

	str = str .. "\n```"

	return {
		contents = {
			kind = "markdown",
			value = str,
		},
		range = {
			start = {
				line = data.line_start-1,
				character = data.character_start,
			},
			["end"] = {
				line = data.line_stop-1,
				character = data.character_stop+1,
			},
		}
	}
end

server:Loop()
