io.stdout:setvbuf("no")
io.stderr:setvbuf("no")
io.flush()
--if not ... then return end

local ffi = require("ffi")
ffi.cdef("int chdir(const char *filename); int usleep(unsigned int usec);")
ffi.C.chdir("/home/caps/oh/")

local json = require("vscode.server.json")
local oh = require("oh")
local helpers = require("oh.helpers")
local tprint = require("examples.util").TablePrint
local server = _G.SERVER or require("vscode.server.lsp")
_G.SERVER = server

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

local document_cache = {}

local function compile(uri, server, client)
	local code = document_cache[uri]

	if not code then
		local f = assert(io.open(uri:sub(#"file://" + 1), "r"))
		code = f:read("*all")
		f:close()
		document_cache[uri] = code
	end

	local file = oh.Code(code, uri, {annotate = true})

	local resp = {
		method = "textDocument/publishDiagnostics",
		params = {
			uri = uri,
			diagnostics = {},
		}
	}

	function file:OnError(msg, start, stop, ...)
		msg = helpers.FormatMessage(msg, ...)
		local data = helpers.SubPositionToLinePosition(code, start, stop)

		if not data then
			local code = io.open(oh.GetBaseAnalyzer().path):read("*all")
			data = helpers.SubPositionToLinePosition(code, start, stop)
			if not data then
				print("INTERNAL ERROR: ", self, msg, start, stop, ...)
				return
			end
		end

		table.insert(resp.params.diagnostics, {
			severity = DiagnosticSeverity.error,
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

	print("analyzing " .. uri)
	file:Analyze()

	server:Respond(client, resp)

	return code, file.Tokens, file.Syntaxtree
end

function server:HandleMessage(resp, client)
	print(resp.method)
	if resp.method == "initialize" then
		self:Respond(client, {
			id = resp.id,
			result = {
				capabilities = {
					textDocumentSync = {
						openClose = true,
						change = TextDocumentSyncKind.Full,
					},
					hoverProvider = true,
					completionProvider = {
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
					},
				}
			},
		})
		return
	elseif resp.method == "textDocument/didOpen" then

		document_cache[resp.params.textDocument.uri] = assert(resp.params.textDocument.text)

		compile(resp.params.textDocument.uri, self, client)






	elseif resp.method == "textDocument/didSave" then

		document_cache[resp.params.textDocument.uri] = nil

		if resp.params.textDocument.uri:find("oh/vscode/server/") then
			local ok, err = pcall(function() assert(loadfile(resp.params.textDocument.uri:sub(#"file://" + 1)))() end)
			if not ok then
				print("error loading " .. resp.params.textDocument.uri .. ": " .. err)
			end
		end
	elseif resp.method == "textDocument/didChange" then
		document_cache[resp.params.textDocument.uri] = assert(resp.params.contentChanges[1].text)
		compile(resp.params.textDocument.uri, self, client)
	elseif resp.method == "textDocument/hover" then
		local code, tokens = compile(resp.params.textDocument.uri, self, client)
		local pos = resp.params.position

		local token, data = helpers.GetDataFromLineCharPosition(tokens, code, pos.line + 1, pos.character + 1)

		if not token then
			self:Respond(client, {
				id = resp.id,
				result = {
					contents = "cannot find anything at " .. resp.params.textDocument.uri .. ":" .. pos.line .. ":" .. pos.character,
				},
			})
			return
		end


		local found = {}
		local node = token
		repeat
			table.insert(found, node)
			node = node.parent
		until not node

		local str = ""

		for i,v in ipairs(found) do
			if v.inferred_type then
				str = str .. "\n```lua\n"
				str = str .. tostring(v.inferred_type)
				str = str .. "\n```\n"
				break
			end
		end

		if token and token.parent then
			local min, max = helpers.LazyFindStartStop(token.parent)
			if min then
				data = helpers.SubPositionToLinePosition(code, min, max)
			end
		end

		self:Respond(client, {
			id = resp.id,
			result = {
				contents = str,
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
			},
		})
		return
	end

	if not resp.method then
		tprint(resp)
		return
	end

	if resp.params.id then
		if resp.method:sub(1,1) == "$" then
			print("responding to " .. resp.method .. " id " .. resp.params.id)

			self:Respond(client, {
				id = resp.id,
				method = resp.method,
				result = json.null,
			})
		else
			print("responding to " .. resp.method .. " id " .. resp.id)

			self:Respond(client, {
				id = resp.id,
				method = resp.method,
				result = json.null,
			})
		end
	end
end

if not server.clients then
	server:Loop()
end