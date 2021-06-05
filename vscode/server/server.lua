io.stdout:setvbuf("no")
io.stderr:setvbuf("no")
io.flush()

local ffi = require("ffi")
local json = require("nattlua.other.json")
local nl = require("nattlua")
local helpers = require("nattlua.other.helpers")
local table_print = require("examples.util").TablePrint
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

local function compile(uri, server, client)
	local f = assert(io.open(uri:sub(#"file://" + 1), "r"))
	local code = f:read("*all")
	f:close()

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

	--compiler:Analyze()
	server:Respond(client, resp)

	return code, compiler:Lex().Tokens, compiler:Parse().SyntaxTree
end

server.methods["initialize"] = function(params, self, client) 
	return {
		capabilities = {
			textDocumentSync = {
				openClose = true,
				change = TextDocumentSyncKind.Full,
			},
			hoverProvider = true,
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

server.methods["textDocument/didOpen"] = function(params, self, client) end
server.methods["textDocument/didChange"] = function(params, self, client) end
server.methods["textDocument/didSave"] = function(params, self, client) end

server.methods["textDocument/hover"] = function(params, self, client)
	local code, tokens = compile(params.textDocument.uri, self, client)
	local pos = params.position

	print("FINDING TOKEN FROM: ", pos.line + 1, pos.character + 1)

	local token, data = helpers.GetDataFromLineCharPosition(tokens, code, pos.line + 1, pos.character + 1)
	
	if not token then
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

	local function add_code(str)
		markdown = markdown .. "```lua\n" .. tostring(str) .. "\n```\n\n"
	end
	
	add_code("[token - " .. token.type .. " (" .. token.value .. ")]")

	markdown = markdown .. "parents:\n\n"

	for _, node in ipairs(found_parents) do
		add_code("\t" .. tostring(node))

		if node.inferred_type then
			add_code(node.inferred_type)
			break
		end
	end

	if token and token.parent then
		local min, max = helpers.LazyFindStartStop(token.parent)
		if min then
			data = helpers.SubPositionToLinePosition(add_code, min, max)
		end
	end

	return {
		contents = markdown,
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
