local ffi = require("ffi")
local ljsocket = require("language_server.server.ljsocket")
local lsp = require("language_server.server.lsp")
local json = require("nattlua.other.json")
local rpc_util = require("nattlua.other.jsonrpc")

return function(port)
	port = port or 1337
	
	_G.VSCODE_PLUGIN = true
	local server = {}
	server.methods = {}

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

	function server:Respond(client, res)
		local encoded = json.encode(res)
		local msg = string.format("Content-Length: %d\r\n\r\n%s", #encoded, encoded)
		client:send(msg)
	end
	
	function server:Loop()
		self.responses = {}
		local socket = assert(ljsocket.create("inet", "stream", "tcp"))
		assert(socket:set_blocking(false))
		socket:set_option("nodelay", true, "tcp")
		socket:set_option("reuseaddr", true)
		socket:bind("*", port)
		assert(socket:listen())
		io.write("HOSTING AT: *:"..port.."\n")
		local clients = {}
		server.clients = clients

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
		end
	end

	for k, v in pairs(lsp.methods) do
		server.methods[k] = v
	end

	function lsp.Call(params)
		for _, client in ipairs(server.clients) do
			server:Respond(client, params)
		end
	end

	ffi.cdef("int chdir(const char *filename); int usleep(unsigned int usec);")
	io.stdout:setvbuf("no")
	io.stderr:setvbuf("no")
	io.flush()
	server:Loop()
end