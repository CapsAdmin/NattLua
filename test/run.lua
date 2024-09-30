local get_time = require("test.helpers.get_time")
local preprocess = require("test.helpers.preprocess")
local coverage = require("test.helpers.coverage")
local profiler = require("test.helpers.profiler")
local io = require("io")
local io_write = _G.ON_EDITOR_SAVE and function(...) end or io.write
local pcall = _G.pcall
require("test.environment")
local path = ...
local is_coverage = path == "coverage"

if is_coverage then path = nil end

if path == "remove_coverage" then
	local util = require("examples.util")
	local paths = util.GetFilesRecursively("./", "lua.coverage")

	for _, path in ipairs(paths) do
		os.remove(path)
	end

	return
end

local covered = {}

if is_coverage then
	preprocess.Init()

	function preprocess.Preprocess(code, name, path, from)
		if from == "package" then
			if path and path:find("^nattlua/") and not path:find("^nattlua/other") then
				covered[name] = path
				return coverage.Preprocess(code, name)
			end
		end

		return code
	end
end

local function find_tests(path)
	if path and path:sub(-5) == ".nlua" then return {path} end

	local what = path
	local path = "test/" .. ((what and what .. "/") or "tests/")
	local cmd = "find"

	if jit and jit.os == "Windows" then
		cmd = "dir /s /b"
		path = path:gsub("/", "\\")
	end

	local analyzer = {}
	local analyzer_complex = {}
	local types = {}
	local other = {}

	for path in io.popen(cmd .. " " .. path):lines() do
		if jit and jit.os == "Windows" then path = path:gsub("\\", "/") end

		path = path:gsub("//", "/")

		if not path:find("/file_importing/", nil, true) then
			if path:find("nattlua/project.lua", nil, true) then
				table.insert(analyzer_complex, path)
			elseif path:find("nattlua/analyzer/", nil, true) then
				if path:find("analyzer/complex", nil, true) then
					table.insert(analyzer_complex, path)
				else
					table.insert(analyzer, path)
				end
			elseif path:find("nattlua/types/", nil, true) then
				table.insert(types, path)
			else
				table.insert(other, path)
			end
		end
	end

	table.sort(analyzer)
	table.sort(analyzer_complex)
	table.sort(types)
	table.sort(other)
	local found = {}

	for i, v in ipairs(other) do
		table.insert(found, v)
	end

	for i, v in ipairs(types) do
		table.insert(found, v)
	end

	for i, v in ipairs(analyzer) do
		table.insert(found, v)
	end

	for i, v in ipairs(analyzer_complex) do
		table.insert(found, v)
	end

	return found
end

local function format_time(seconds)
	local str = ("%.3f"):format(seconds)

	if seconds > 0.5 then return "\x1b[0;31m" .. str .. " seconds\x1b[0m" end

	return str
end

local total = 0
local time_taken_before_tests = os.clock()

if STARTUP_PROFILE then
	io_write("== startup profiling == :")
	profiler.Stop()
	io_write("== == :")
end

if not _G.ON_EDITOR_SAVE then profiler.Start() end

if path and path:sub(-4) == ".lua" then
	io_write(path, " ")
	local time = get_time()
	assert(loadfile(path))()
	io_write(" ", format_time(get_time() - time), " seconds\n")
else
	local tests = find_tests(path)

	for _, path in ipairs(tests) do
		if path:sub(-4) == ".lua" then
			io_write((path:gsub("test/tests/", "")), " ")
			local func = assert(loadfile(path))
			local time = get_time()
			func()
			local diff = get_time() - time
			total = total + diff
			io_write(" ", format_time(diff), " seconds\n")
		end
	end

	for _, path in ipairs(tests) do
		if path:sub(-5) == ".nlua" then
			io_write((path:gsub("test/tests/", "")), " ")
			local f = assert(io.open(path, "r"))
			local str = assert(f:read("*all"))
			f:close()
			local time = get_time()
			analyze(str)
			local diff = get_time() - time
			total = total + diff
			io_write(" ", format_time(diff), " seconds\n")
		end
	end
end

if is_coverage then
	for name, path in pairs(covered) do
		local coverage = coverage.Collect(name)

		if coverage then
			local f = assert(io.open(path .. ".coverage", "w"))
			f:write(coverage)
			f:close()
		else
			print("unable to find coverage information for " .. name)
		end
	end
end

if not _G.ON_EDITOR_SAVE then profiler.Stop() end

if total > 0 then
	io_write("all tests together took ", format_time(total), " seconds\n")
	io_write(
		"startup time (from program start to first tests run) took ",
		format_time(time_taken_before_tests),
		" seconds\n"
	)
end

os.exit() -- no need to wait for gc to complete
