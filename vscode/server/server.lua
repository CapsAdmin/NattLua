io.stdout:setvbuf("no")
io.stderr:setvbuf("no")

print("HELLO WORLD")

io.flush()
--if not ... then return end

local ffi = require("ffi")
ffi.cdef("int chdir(const char *filename); int usleep(unsigned int usec);")
ffi.C.chdir("/home/caps/oh/")

local oh = require("oh")
local helpers = require("oh.helpers")
local tprint = require("oh.util").TablePrint
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

	function file:OnError(msg, start, stop, ...)
		print(msg, start, stop)
		msg = helpers.FormatMessage(msg, ...)
		local data = helpers.SubPositionToLinePosition(code, start, stop)

		if not data then
			print("INTERNAL ERROR: ", self, msg, start, stop, ...)
			return
		end

		local resp = {
			method = "textDocument/publishDiagnostics",
			params = {
				uri = uri,
				diagnostics = {
					{
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
					}
				}
			}
		}

		server:Respond(client, resp)
	end

	file:Analyze()


	return code, file.Tokens, file.Syntaxtree
end

function server:HandleMessage(resp, client)
	print(resp.method)
	if resp.method == "initialize" then
		self:Respond(client, {
			id = resp.id,
			result = {
				capabilities = {
					textDocumentSync = TextDocumentSyncKind.Full,
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
		document_cache[resp.params.textDocument.uri] = resp.params.textDocument.text
		compile(resp.params.textDocument.uri, self, client)
	elseif resp.method == "textDocument/didSave" then
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

		local token, expression, statement, data = helpers.GetDataFromLineCharPosition(tokens, code, pos.line + 1, pos.character + 1)

		if not token then
			self:Respond(client, {
				id = resp.id,
				result = {
					contents = "cannot find anything at " .. resp.params.textDocument.uri .. ":" .. pos.line .. ":" .. pos.character,
				},
			})
			return
		end

		local str = ""

		if statement then
			if statement.inferred_type then
				str = str .. "### statement type:\n```lua\n"
				str = str .. tostring(statement.inferred_type)
				str = str .. "\n```\n"
			end

			str = str .. "### statement\n```lua\n"
			str = str .. statement:Render({preserve_whitespace = false, no_comments = true})
			str = str .. "\n```\n"
		end

		if expression then
			if expression.inferred_type then
				str = str .. "# expression type:\n```lua\n"
				str = str .. tostring(expression.inferred_type)
				str = str .. "\n```\n"
			end

			str = str .. "### expression\n```lua\n"
			str = str .. expression:Render({preserve_whitespace = false, no_comments = true})
			str = str .. "\n```\n"

		end

		str = str .. "### token\n```lua\n"
		str = str .. token.value
		str = str .. "\n```\n"

		if expression and expression.inferred_type then
			str = ""

			str = str .. "```lua\n"
			str = str .. tostring(expression.inferred_type)
			str = str .. "\n```\n"
		end

		self:Respond(client, {
			id = resp.id,
			result = {
				contents = str,
			},
			range = data and {
				start = {
					line = data.line_start-1,
					character = data.character_start,
				},
				["end"] = {
					line = data.line_stop-1,
					character = data.character_stop,
				},
			} or nil,
		})
		return
	end

	self:Respond(client, {
		id = resp.id,
		result = true,
	})
end

if not server.clients then
	server:Loop()
end