local ffi = require("ffi")
local ljsocket = require("vscode.server.ljsocket")
ffi.cdef("int chdir(const char *filename); int usleep(unsigned int usec);")
ffi.C.chdir("/home/caps/nl/")
local rpc_util = require("nattlua.other.jsonrpc")
local files = {}

local function lazy_file_changed(path)
	local f = assert(io.open(path, "r"))
	local code = f:read("*all")
	f:close()

	if files[path] and files[path] ~= code then
		files[path] = nil
		return true
	end

	files[path] = code
	return false
end

local LSP_VERSION = "3.16"
local LSP_ERRORS = {
	SERVER_NOT_INITALIZED = {
		code = -32002,
		message = "Server not initialized",
	},
	UNKNOWN_ERROR = {code = -32001, message = "Unknown error"},
	REQUEST_CANCELLED = {code = -32800, message = "Request Cancelled"},
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
local server = {}
server.methods = {}

function server:ShowMessage(client, type, msg)
	self:Respond(
		client,
		{
			method = "window/showMessage",
			params = {
				type = assert(MessageType[type]),
				message = msg,
			},
		}
	)
end

function server:LogMessage(client, type, msg)
	self:Respond(
		client,
		{
			method = "window/logMessage",
			params = {
				type = assert(MessageType[type]),
				message = msg,
			},
		}
	)
end

function server:OnError(msg)
	error(msg)
end

function server:OnReceiveBody(client, str)
	table.insert(
		self.responses,
		{
			client = client,
			thread = coroutine.create(function()
				local res = rpc_util.ReceiveJSON(str, self.methods, self, client)

				if res.error then table.print(res) end

				return res
			end),
		}
	)
end

local json = require("nattlua.other.json")

function server:Respond(client, res)
	local encoded = json.encode(res)
	local msg = string.format("Content-Length: %d\r\n\r\n%s", #encoded, encoded)
	client:send(msg)
end

function server:Loop()
	self.responses = {}
	local socket = ljsocket.create("inet", "stream", "tcp")
	assert(socket:set_blocking(false))
	socket:set_option("nodelay", true, "tcp")
	socket:set_option("reuseaddr", true)
	socket:bind("*", 1337)
	assert(socket:listen())
	io.write("HOSTING AT: *:1337\n")
	local clients = {}

	while true do
		local client, err = socket:accept()

		if client then
			assert(client:set_blocking(false))
			client:set_option("nodelay", true, "tcp")
			client:set_option("cork", false, "tcp")
			print("client joined", client)
			table.insert(clients, client)
		end

		for i = #clients, 1, -1 do
			local client = clients[i]
			local chunk, err = client:receive()

			if err and err ~= "timeout" then print(client, chunk, err) end

			local body = rpc_util.ReceiveHTTP(client, chunk)

			if body then self:OnReceiveBody(client, body) end

			if not chunk then
				if err == "closed" then
					table.remove(clients, i)
				elseif err ~= "timeout" then
					table.remove(clients, i)
					client:close()
					print("error: ", err)
				end
			end
		end

		for i = #self.responses, 1, -1 do
			local data = self.responses[i]
			local ok, msg = coroutine.resume(data.thread)

			if not ok then
				if msg ~= "suspended" then table.remove(self.responses, i) end
			else
				if type(msg) == "table" then
					self:Respond(data.client, msg)
					table.remove(self.responses, i)
				end
			end
		end

		ffi.C.usleep(50000)

		if
			lazy_file_changed("language_server/server/lsp.lua") or
			lazy_file_changed("language_server/server/server.lua")
		then
			print("hot reload")

			for _, client in ipairs(clients) do
				client:close()
			end

			socket:close()
			RESTART = os.clock() + 0.1
		end

		if RESTART and RESTART < os.clock() then
			print("restarting")
			loadfile("language_server/server/server.lua")()
			return
		end
	end
end

return server
