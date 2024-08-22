-- Redirect print function to stderr for debug output
local ffi = require("ffi")
local lsp = require("language_server.server.lsp")
local json = require("nattlua.other.json")
local rpc_util = require("nattlua.other.jsonrpc")
local INPUT = io.stdin
local OUTPUT = io.stderr -- using STDERR explcitly to have a clean channel
local function read_message()
	local line = INPUT:read("*l")

	if not line then return nil end

	local content_length = tonumber(line:match("Content%-Length: (%d+)"))
	INPUT:read("*l") -- Read the empty line
	return INPUT:read(content_length)
end

local function write_message(message)
	local encoded = json.encode(message)
	OUTPUT:write(string.format("Content-Length: %d\r\n\r\n%s", #encoded, encoded))
	io.flush()
end

OUTPUT:setvbuf("no")

function lsp.Call(params)
	write_message(params)
end

while true do
	local body = read_message()
	local res = rpc_util.ReceiveJSON(body, lsp.methods)

	if res then
		if res.error then error(res.error.message) end

		write_message(res)
	end
end
