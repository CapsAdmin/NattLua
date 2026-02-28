-- Redirect print function to stderr for debug output
local ffi = require("ffi")
local lsp = require("language_server.lsp")
local json = require("language_server.json")
local rpc_util = require("language_server.jsonrpc")
local INPUT = io.stdin
local OUTPUT = io.stderr -- using STDERR explcitly to have a clean channel
local session_output = io.open("lsp_session_out.rpc", "w")
local session_input = io.open("lsp_session_in.rpc", "w")
io.stdout:setvbuf("no")

local function read_message()
	local line = INPUT:read("*l")

	while line and not line:match("Content%-Length:") do
		line = INPUT:read("*l")
	end

	if not line then return nil end

	local content_length = tonumber(line:match("Content%-Length: (%d+)"))

	if not content_length then return nil end

	-- Skip any other headers until we find the empty line
	while line and line ~= "" and line ~= "\r" do
		line = INPUT:read("*l")
	end

	local str = INPUT:read(content_length)

	if session_input then
		session_input:write(str, "\n\n")
		session_input:flush()
	end

	return str
end

local function write_message(message)
	local encoded = json.encode(message)
	local data = string.format("Content-Length: %d\r\n\r\n%s", #encoded, encoded)
	OUTPUT:write(data)
	OUTPUT:flush()

	if session_output then
		session_output:write(data)
		session_output:flush()
	end
end

OUTPUT:setvbuf("no")

function lsp.Call(params)
	write_message(params)
end

local function update()
	local body = read_message()
	local res = rpc_util.ReceiveJSON(body, lsp.methods)

	if res then
		if res.error then
			table.print(res)
			error(res.error.message)
		end

		write_message(res)
	end
end

while true do
	local ok, err = pcall(update)

	if not ok then print(err) end
end