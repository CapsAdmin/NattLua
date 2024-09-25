-- Redirect print function to stderr for debug output
local ffi = require("ffi")
local lsp = require("language_server.lsp")
local json = require("language_server.json")
local rpc_util = require("language_server.jsonrpc")
local INPUT = io.stdin
local OUTPUT = io.stderr -- using STDERR explcitly to have a clean channel
local session = io.open("lsp_session.rpc", "w")

local function read_message()
	local line = INPUT:read("*l")

	if not line then return nil end

	local content_length = tonumber(line:match("Content%-Length: (%d+)"))
	INPUT:read("*l") -- Read the empty line
	return INPUT:read(content_length)
end

-- Without this, it seems like vscode will error as the body length deviates from content-length with unicode characters
-- I initially thought utf8.length would work, but that doesn't seem to be it.
local function escape_unicode(c)
	return string.format("\\u%04x", c:byte())
end

local function write_message(message)
	local encoded = json.encode(message)
	encoded = encoded:gsub("([\x80-\xff])", escape_unicode)
	local data = string.format("Content-Length: %d\r\n\r\n%s", #encoded, encoded)
	OUTPUT:write(data)
	OUTPUT:flush()
	session:write(data)
	session:flush()
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
