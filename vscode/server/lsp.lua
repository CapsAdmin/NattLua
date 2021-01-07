local ffi = require("ffi")
ffi.cdef("int chdir(const char *filename); int usleep(unsigned int usec);")
ffi.C.chdir("/home/caps/nl/")

local JSON_RPC_VERSION = "3.15"

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

local server = require("vscode.server.tcp_server")()
local json = require("vscode.server.json")

function server:OnClientConnected(client)
	self.clients = self.clients or {}
	table.insert(self.clients, client)
	function client:OnReceiveChunk(str)
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

function server:OnError(msg)
    error(msg)
end

function server:OnReceive(str, client)
	local ok, data = pcall(json.decode, str)
	if ok then
		xpcall(
			function() return self:HandleMessage(data, client) end, function(msg)
			self:ShowMessage(client, "error", debug.traceback(msg))
		end)
	else
		print("error!")
		print(data)
		print(">" .. str .. "<")
	end
end

function server:Respond(client, res)
	res.jsonrpc = JSON_RPC_VERSION
	local encoded = json.encode(res)
	local msg = string.format("Content-Length: %d\r\n\r\n%s", #encoded, encoded)
	client:Send(msg)
end

function server:Loop()
    --os.execute("fuser -k 1337/tcp")

    server:Host("*", 1337)

	io.write("HOSTING AT: *:1337\n")

    while true do
        self:Update()
        if self.clients then
            for i,v in ipairs(self.clients) do
                v:Update()
            end
        end

        ffi.C.usleep(50000)
    end
end

return server