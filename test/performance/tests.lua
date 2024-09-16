require("nattlua.other.jit_options")()
require("test.environment")
local profiler = require("nattlua.other.profiler")
local io_write = io.write

local function format_time(seconds)
	local str = ("%.3f"):format(seconds)

	if seconds > 0.5 then return "\x1b[0;31m" .. str .. " seconds\x1b[0m" end

	return str
end

profiler.Start()
local time = os.clock()

do
	local tests = {
		"test/nattlua/lsp/editor.lua",
		"test/nattlua/luajit_project.lua",
		"test/nattlua/analyzer/complex/self/tuple.nlua",
		"test/nattlua/analyzer/complex/self/union.nlua",
		"test/nattlua/c_declarations/cdef.nlua",
		"test/nattlua/analyzer/complex/self/string.nlua",
		"test/nattlua/analyzer/complex/self/lexer.nlua",
		"test/nattlua/analyzer/complex/self/base_parser.nlua",
		"test/nattlua/analyzer/complex/ljsocket.nlua",
		"test/nattlua/analyzer/complex/cdata.nlua",
		"test/nattlua/analyzer/load.lua",
		"test/nattlua/analyzer/lua.lua",
	}

	for _, path in ipairs(tests) do
		if path:sub(-4) == ".lua" then
			io_write(path, " ")
			local time = os.clock()
			assert(loadfile(path))()
			io_write(" ", format_time(os.clock() - time), " seconds\n")
		end
	end

	for _, path in ipairs(tests) do
		if path:sub(-5) == ".nlua" then
			local time = os.clock()
			io_write(path, " ")
			analyze(io.open(path, "r"):read("*all"))
			io_write(" ", format_time(os.clock() - time), " seconds\n")
		end
	end
end

local time = format_time(os.clock() - time)
profiler.Stop()
io_write(" ", time, " seconds\n")