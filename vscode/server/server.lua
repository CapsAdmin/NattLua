if false then
	local suppress = false

	io.write = function(...)
		for i = 1, select("#", ...) do
			local val = select(i, ...)
			val = tostring(val)
			if _G.IO_WRITE and not suppress then
				suppress = true
				IO_WRITE(val)
				suppress = false
			end
			io.stdout:write(val)
		end
	end

	print = function(...)
		for i = 1, select("#", ...) do
			local val = select(i, ...)
			val = tostring(val)

			if i ~= select("#", ...) then
				val = val .. "\t"
			else
				val = val .. "\n"
			end

			if _G.IO_WRITE and not suppress then
				suppress = true
				IO_WRITE(val)
				suppress = false
			end
			io.stdout:write(val)
		end
	end
end


local ffi = require("ffi")
ffi.cdef("int chdir(const char *filename); int usleep(unsigned int usec);")
ffi.C.chdir("/home/caps/oh/")

local json = require("vscode.server.json")
local tcp_server = require("vscode.server.tcp_server")
local tprint = require("oh.util").TablePrint

local JSON_RPC_VERSION = "2.0"

-- Constants as defined by the JSON-RPC 2.0 specification
local JSON_RPC_ERROR = {
	PARSE = {
		code = -32700,
		message = "Parse error",
	},
	REQUEST = {
		code = -32600,
		message = "Invalid request",
	},
	UNKNOWN_METHOD = {
		code = -32601,
		message = "Unknown method",
	},
	INVALID_PARAMS = {
		code = -32602,
		message = "Invalid parameters",
	},
	INTERNAL_ERROR = {
		code = -32603,
		message = "Internal error",
	},
	SERVER_NOT_INITALIZED = {
		code = -32002,
		message = "Server not initialized",
	},
	UNKNOWN_ERROR = {
		code = -32001,
		message = "Unknown error"
	},
	REQUEST_CANCELLED = {
		code = -32800,
		message = "Request Cancelled"
	},
	-- -32000 to -32099 is reserved for implementation-defined server-errors
}

local LSP_ERROR = -32000

-- LSP Protocol constants
local DiagnosticSeverity = {
	Error = 1,
	Warning = 2,
	Information = 3,
	Hint = 4,
}

local TextDocumentSyncKind = {
	None = 0,
	Full = 1,
	Incremental = 2,
}

local MessageType = {
	error = 1,
	warning = 2,
	info = 3,
	log = 4,
}

local FileChangeType = {
	Created = 1,
	Changed = 2,
	Deleted = 3,
}

local CompletionItemKind = {
	Text = 1,
	Method = 2,
	Function = 3,
	Constructor = 4,
	Field = 5,
	Variable = 6,
	Class = 7,
	Interface = 8,
	Module = 9,
	Property = 10,
	Unit = 11,
	Value = 12,
	Enum = 13,
	Keyword = 14,
	Snippet = 15,
	Color = 16,
	File = 17,
	Reference = 18,
}

-- LSP line and character indecies are zero-based
local function position(line, column)
	return { line = line-1, character = column-1 }
end

local function range(s, e)
	return { start = s, ['end'] = e }
end

local server = LOLSERVER

if not server then
    server = tcp_server()
	server:Host("*", 1337)
	io.write("HOSTING AT: *:1337\n")
end

function server:OnClientConnected(client)
	self.clients = self.clients or {}
	table.insert(self.clients, client)
	function client:OnReceiveChunk(str)
		local chunk = str
		local header = str:match("^(Content%-Length: %d+%s+)")
		if header then
			local size = header:match("Length: (%d+)")

			local data = str:sub(#header+1, #header + size)
			if data ~= "" then
				server:OnReceive(data, client)
			end

			local next = str:sub(size + 1, #str)
			if next ~= "" then
				self:OnReceiveChunk(next)
				return
			end
		end


    end
end

function server:ShowMessage(client, type, msg)
	self:Respond(client, {
		method = "window/showMessage",
		params = {
			type = assert(MessageType[type]),
			message = msg,
		}
	})
end

function server:LogMessage(client, type, msg)
	self:Respond(client, {
		method = "window/logMessage",
		params = {
			type = assert(MessageType[type]),
			message = msg,
		}
	})
end

do
	local buffer = ""
	function IO_WRITE(str)
		buffer = buffer .. str
		while true do
			local _, stop = buffer:find("\n", 1, true)
			if stop then
				server:LogMessage(server.clients[1], "log", buffer:sub(stop-1))
				buffer = buffer:sub(stop + 1)
			else
				break
			end
		end
	end
end

function server:OnReceive(str, client)
	local ok, data = pcall(json.decode, str)
	if ok then
		xpcall(self.HandleMessage, function(msg)
			self:ShowMessage(client, "error", debug.traceback(msg))
		end, self, data, client)
	else
		print("error!")
		print(data)
		print(">" .. str .. "<")
	end
end

function server:Respond(client, res)
	res.jsonrpc = "2.0"
    local encoded = json.encode(res)
	local msg = string.format("Content-Length: %d\r\n\r\n%s", #encoded, encoded)
	print(msg)
    client:Send(msg)
end

local Lexer = require("oh.lua.lexer")
local Parser = require("oh.lua.parser")
local LuaEmitter = require("oh.lua.emitter")
local Analyzer = require("oh.lua.analyzer")
local helpers = require("oh.helpers")

local oh = require("oh")

local document_cache = {}

local function compile(uri, server, client)
	local code = document_cache[uri]
	if not code then
		local f = assert(io.open(uri:sub(#"file://" + 1), "r"))
		print(uri, "!!!")
		code = f:read("*all")
		f:close()
		document_cache[uri] = code
	end
	local resp = {
		method = "textDocument/publishDiagnostics",
		params = {
			uri = uri,
			diagnostics = {}
		}
	}

	local file = oh.Code(code, "test", {annotate = true})
	function file:OnError(msg, start, stop, ...)
		msg = helpers.FormatMessage(msg, ...)
		local data = helpers.SubPositionToLinePosition(code, start, stop)

		if not data then
			print(self, msg, start, stop, ...)
			return
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
	file:Analyze()

	return file.Tokens, file.Syntaxtree
end

function server:HandleMessage(resp, client)
	print(resp.method)
	if resp.method == "initialize" and resp.id then
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
				}
			},
		})
	elseif resp.method == "textDocument/didOpen" then
		--tprint(resp)
		document_cache[resp.params.textDocument.uri] = resp.params.textDocument.text
		compile(resp.params.textDocument.uri, self, client)
	elseif resp.method == "textDocument/didChange" then
		--tprint(resp)
		--document_cache[resp.params.textDocument.uri] = resp.params.contentChanges[1].text
		compile(resp.params.textDocument.uri, self, client)
	elseif resp.method == "textDocument/hover" then
		local pos = resp.params.position
		local tokens, ast = compile(resp.params.textDocument.uri, self, client)
		local code = assert(document_cache[resp.params.textDocument.uri])

		local sub_pos = helpers.LinePositionToSubPosition(code, pos.line + 1, pos.character)

		for i,v in ipairs(tokens) do
			if sub_pos >= v.start and sub_pos <= v.stop then
				local data = helpers.SubPositionToLinePosition(code, v.start, v.stop)

				self:Respond(client, {
					id = resp.id,
					result = {
						contents = v.parent and v.parent:Render({annotate = true}) or v.value,
					},
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
				})
				break
			end
		end
	else--if resp.method ~= "$/cancelRequest" then
		--tprint(resp)
	end
end

LOLSERVER = server

while true do
	LOLSERVER:Update()
	if LOLSERVER.clients then
		for i,v in ipairs(LOLSERVER.clients) do
			v:Update()
		end
	end

	ffi.C.usleep(50000)
end