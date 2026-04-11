-- Redirect print function to stderr for debug output
local ffi = require("ffi")
local lsp = require("language_server.lsp")
local json = require("language_server.json")
local rpc_util = require("language_server.jsonrpc")
local OUTPUT = io.stderr -- using STDERR explcitly to have a clean channel
local session_output = io.open("lsp_session_out.rpc", "w")
local session_input = io.open("lsp_session_in.rpc", "w")
io.stdout:setvbuf("no")

ffi.cdef[[
typedef long ssize_t;
typedef unsigned long nfds_t;
struct pollfd {
	int fd;
	short events;
	short revents;
};
int poll(struct pollfd *fds, nfds_t nfds, int timeout);
ssize_t read(int fd, void *buf, size_t count);
]]

local INPUT_FD = 0
local POLLIN = 0x001
local READ_CHUNK_SIZE = 65536
local JSONRPC_REQUEST_CANCELLED = -32800
local input_state = {buffer = ""}

local function record_input(str)
	if session_input then
		session_input:write(str, "\n\n")
		session_input:flush()
	end
end

local function read_message_from_buffer()
	local str = rpc_util.ReceiveHTTP(input_state, nil)

	if str then record_input(str) end

	return str
end

local function read_message(timeout)
	local str = read_message_from_buffer()

	if str then return str end

	local fds = ffi.new("struct pollfd[1]")
	fds[0].fd = INPUT_FD
	fds[0].events = POLLIN

	if ffi.C.poll(fds, 1, timeout) <= 0 then return nil end

	while true do
		local buffer = ffi.new("char[?]", READ_CHUNK_SIZE)
		local read = ffi.C.read(INPUT_FD, buffer, READ_CHUNK_SIZE)

		if read <= 0 then return nil end

		str = rpc_util.ReceiveHTTP(input_state, ffi.string(buffer, read))

		if str then
			record_input(str)
			return str
		end

		str = read_message_from_buffer()

		if str then return str end

		if ffi.C.poll(fds, 1, 0) <= 0 then return nil end
	end
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

local function decode_message(body)
	local ok, rpc = pcall(json.decode, body)

	if ok then return rpc end
end

local function cancellation_response(id)
	return {
		jsonrpc = "2.0",
		id = id,
		error = {
			code = JSONRPC_REQUEST_CANCELLED,
			message = "Request cancelled",
		},
	}
end

local pending = {}
local active_job = nil

local function enqueue_message(body)
	local rpc = decode_message(body)

	if type(rpc) == "table" and rpc.method == "$/cancelRequest" and rpc.id == nil then
		lsp.CancelRequest(rpc.params and rpc.params.id)
		return
	end

	pending[#pending + 1] = {body = body, rpc = rpc}
end

local function start_job(entry)
	local id = type(entry.rpc) == "table" and entry.rpc.id or nil

	active_job = {
		id = id,
		co = coroutine.create(function()
			return rpc_util.ReceiveJSON(entry.body, lsp.methods)
		end),
	}
end

local function finish_job(response)
	if response then write_message(response) end

	if active_job and active_job.id ~= nil then
		lsp.ClearCancelledRequest(active_job.id)
	end

	active_job = nil
end

local function step_job()
	if not active_job then return end

	if active_job.id ~= nil and lsp.IsRequestCancelled(active_job.id) then
		finish_job(cancellation_response(active_job.id))
		return
	end

	local ok, response = coroutine.resume(active_job.co)

	if not ok then
		print(response)

		if active_job.id ~= nil then
			finish_job({
				jsonrpc = "2.0",
				id = active_job.id,
				error = {
					code = -32603,
					message = tostring(response),
				},
			})
		else
			finish_job(nil)
		end

		return
	end

	if coroutine.status(active_job.co) == "dead" then finish_job(response) end
end

while true do
	local ok, err = pcall(function()
		if active_job then
			local body = read_message(0)

			while body do
				enqueue_message(body)
				body = read_message(0)
			end

			step_job()
		else
			if not pending[1] then
				local body = read_message(-1)

				if not body then return end

				enqueue_message(body)
			end

			if pending[1] then start_job(table.remove(pending, 1)) end
		end
	end)

	if not ok then print(err) end
end
