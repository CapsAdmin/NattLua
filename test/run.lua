local preprocess = require("nattlua.other.preprocess")
local coverage = require("nattlua.other.coverage")
local profiler = require("nattlua.other.profiler")
local io = require("io")
local io_write = _G.ON_EDITOR_SAVE and function(...) end or io.write
local pcall = _G.pcall

if not _G.ON_EDITOR_SAVE then profiler.Start() end

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
	local path = "test/" .. ((what and what .. "/") or "nattlua/")
	local found = {}

	for path in io.popen("find " .. path):lines() do
		path = path:gsub("//", "/")

		if not path:find("/file_importing/", nil, true) then
			table.insert(found, path)
		end
	end

	table.sort(found)
	return found
end

local function format_time(seconds)
	local str = ("%.3f"):format(seconds)

	if seconds > 0.5 then return "\x1b[0;31m" .. str .. " seconds\x1b[0m" end

	return str
end

if path and path:sub(-4) == ".lua" then
	io_write(path, " ")
	local time = os.clock()
	assert(loadfile(path))()
	io_write(" ", format_time(os.clock() - time), " seconds\n")
else
	local tests = find_tests(path)

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