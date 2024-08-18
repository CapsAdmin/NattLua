local preprocess = require("nattlua.other.preprocess")
local coverage = require("nattlua.other.coverage")
local profiler = require("nattlua.other.profiler")
local io = require("io")
local io_write = _G.ON_EDITOR_SAVE and function(...) end or io.write
local pcall = _G.pcall
profiler.Start()


--require("nattlua.other.debug").GlobalLookup()

function _G.test(name, cb)
	cb()
end

function _G.pending(...) end

function _G.equal(a, b, level)
	level = level or 1

	if a ~= b then
		if type(a) == "string" then a = string.format("%q", a) end

		if type(b) == "string" then b = string.format("%q", b) end

		error(tostring(a) .. " ~= " .. tostring(b), level + 1)
	end
end

function _G.diff(input, expect)
	local a = os.tmpname()
	local b = os.tmpname()

	do
		local f = assert(io.open(a, "w"))
		f:write(input)
		f:close()
	end

	do
		local f = assert(io.open(b, "w"))
		f:write(expect)
		f:close()
	end

	os.execute("git --no-pager diff --no-index " .. a .. " " .. b)
end


do
	-- reuse an existing environment to speed up tests
	local BuildBaseEnvironment = require("nattlua.runtime.base_environment").BuildBaseEnvironment
	local runtime_env, typesystem_env = BuildBaseEnvironment()
	local nl = require("nattlua")

	function _G.analyze(code, expect_error, expect_warning)
		local info = debug.getinfo(2)
		local name = info.source:match("(test/nattlua/.+)") or info.source

		if not _G.ON_EDITOR_SAVE then
			io.write(".")
			io.flush()
		end

		_G.TEST = true
		local compiler = nl.Compiler(code, nil, nil, 3)
		compiler:SetEnvironments(runtime_env:Copy(), typesystem_env)
		local ok, err = compiler:Analyze()
		_G.TEST = false

		if expect_warning then
			local str = ""

			for _, diagnostic in ipairs(compiler.analyzer:GetDiagnostics()) do
				if diagnostic.msg:find(expect_warning) then return compiler end

				str = str .. diagnostic.msg .. "\n"
			end

			if str == "" then error("expected warning, got\n\n\n" .. str, 3) end

			error("expected warning '" .. expect_warning .. "' got:\n>>\n" .. str .. "\n<<", 3)
		end

		if expect_error then
			if not err or err == "" then
				error(
					"expected error, got nothing\n\n\n[" .. tostring(ok) .. ", " .. tostring(err) .. "]",
					3
				)
			elseif type(expect_error) == "string" then
				if not err:find(expect_error) then
					error("expected error '" .. expect_error .. "' got:\n>>\n" .. err .. "\n<<", 3)
				end
			elseif type(expect_error) == "function" then
				local ok, msg = pcall(expect_error, err)

				if not ok then
					error("error did not pass: " .. msg .. "\n\nthe error message was:\n" .. err, 3)
				end
			else
				error("invalid expect_error argument", 3)
			end
		else
			if not ok then error(err, 3) end
		end

		return compiler.analyzer, compiler.SyntaxTree, compiler.AnalyzedResult
	end
end

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

profiler.Stop()