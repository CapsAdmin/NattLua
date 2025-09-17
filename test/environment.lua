local io = require("io")
local io_write = io.write
local diff = require("nattlua.other.diff")
local fs = require("nattlua.other.fs")
local Table = require("nattlua.types.table").Table
local debug = require("debug")
local pcall = _G.pcall
local type = _G.type
local ipairs = _G.ipairs
local xpcall = _G.xpcall
local assert = _G.assert
local loadfile = _G.loadfile
local get_time = require("test.helpers.get_time")
local profiler = require("test.helpers.profiler")
local jit = _G.jit
local table = _G.table
local collectgarbage = _G.collectgarbage
local colors = require("nattlua.cli.colors")
local BuildBaseEnvironment = require("nattlua.base_environment").BuildBaseEnvironment
local callstack = require("nattlua.other.callstack")
local nl = require("nattlua")

function _G.test(name, cb, start, stop)
	if start and stop then
		local ok_start, err_start = xpcall(start, debug.traceback)
		local ok_cb, err_cb = xpcall(cb, debug.traceback)
		local ok_stop, err_stop = xpcall(stop, debug.traceback)

		-- Report errors in priority order, but only after all functions have run
		if not ok_start then
			error(string.format("Test '%s' setup failed: %s", name, err_start), 2)
		elseif not ok_cb then
			error(string.format("Test '%s' failed: %s", name, err_cb), 2)
		elseif not ok_stop then
			error(string.format("Test '%s' teardown failed: %s", name, err_stop), 2)
		end
	else
		-- If setup/teardown not provided, just run the test
		local ok_cb, err_cb = xpcall(cb, debug.traceback)

		if not ok_cb then
			error(string.format("Test '%s' failed: %s", name, err_cb), 2)
		end
	end
end

function _G.pending(...) end

function _G.equal(a, b, level)
	level = level or 1

	if a ~= b then
		if type(a) == "string" then a = string.format("%q", a) end

		if type(b) == "string" then b = string.format("%q", b) end

		error("\n" .. tostring(a) .. "\n~=\n" .. tostring(b), level + 1)
	end
end

function _G.diff(input, expect)
	print(diff.diff(input, expect))
end

do
	-- reuse an existing environment to speed up tests
	local runtime_env, typesystem_env = BuildBaseEnvironment()

	function _G.analyze(code, expect_error, expect_warning)
		local path = callstack.get_line(2)
		local name = path:match("(test/tests/.+)") or path

		if not _G.HOTRELOAD then _G.loading_indicator() end

		_G.TEST = true
		local compiler = nl.Compiler(code, nil, nil, 3)
		compiler:SetEnvironments(Table({}), typesystem_env)
		_G.TEST_GARBAGE = {}
		local ok, err = compiler:Analyze()

		do
			local tbl = {}

			for k, v in pairs(_G.TEST_GARBAGE) do
				tbl[k:GetHash()] = v
			end

			for hash, v in pairs(tbl) do
				if v and v.Type == "symbol" and v:IsNil() then tbl[hash] = nil end
			end

			if next(tbl) then
				table.print(tbl)
				error("garbage not collected", 2)
			end
		end

		_G.TEST = false

		if expect_warning then
			local str = ""

			for _, diagnostic in ipairs(compiler.analyzer:GetDiagnostics()) do
				if diagnostic.msg:find(expect_warning) then return compiler end

				str = str .. diagnostic.msg .. "\n"
			end

			if str == "" then error("expected warning, got\n\n\n" .. str, 2) end

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

function _G.find_tests(filter)
	local test_directory = fs.get_current_directory() .. "/test/tests/"
	local filtered = {}
	local files = fs.get_files_recursive(test_directory)

	if not filter or filter == "all" then
		filtered = files
	else
		for _, path in ipairs(files) do
			if path:find(filter, nil, true) then table.insert(filtered, path) end
		end
	end

	local analyzer = {}
	local analyzer_complex = {}
	local types = {}
	local other = {}

	for _, path in ipairs(filtered) do
		if fs.is_file(path) then
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

	local expanded = {}

	for i, path in ipairs(found) do
		local is_lua = path:sub(-4) == ".lua"
		local is_nl = path:sub(-5) == ".nlua"
		local name = path:gsub(test_directory, "")
		table.insert(
			expanded,
			{
				path = path,
				name = name,
				is_lua = is_lua,
				is_nl = is_nl,
			}
		)
	end

	return expanded
end

do
	local LOGGING = false
	local PROFILING = false

	local function format_time(seconds)
		local str = ("%.3f"):format(seconds)

		if seconds > 0.5 then return colors.red(str .. "s") end

		return str .. "s"
	end

	local function format_gc(kb)
		if kb > 1024 then
			local str = ("%.2f MB"):format(kb / 1024)

			if kb > 10 * 1024 then return colors.red(str) end
		end

		return ("%.2f KB"):format(kb)
	end

	local i = 0

	function _G.loading_indicator()
		if not LOGGING then return end

		if i % 4 == 0 then
			io_write(colors.dim("."))
			io.flush()
		end

		i = i + 1
	end

	local total = 0
	local total_gc = 0
	local test_count = 0

	function _G.begin_tests(logging, profiling)
		if _G.STOP_STARTUP_PROFILE then
			_G.STOP_STARTUP_PROFILE()
			_G.STOP_STARTUP_PROFILE = nil
		end

		LOGGING = logging or false
		PROFILING = profiling or false

		if PROFILING then profiler.Start() end
	end

	local function run_func(func, ...)
		local gc = collectgarbage("count")
		local time = get_time()
		func(...)
		time = get_time() - time
		gc = collectgarbage("count") - gc

		if LOGGING then
			io_write("\t", format_time(time), " and ", format_gc(gc), "\n")
		end

		total = total + time
		total_gc = total_gc + gc
	end

	function _G.run_single_test(test)
		if LOGGING then io_write(test.name, "\t") end

		if test.is_lua then
			run_func(assert(loadfile(test.path)))
		else
			run_func(analyze, assert(fs.read(test.path)))
		end

		test_count = test_count + 1
	end

	function _G.end_tests()
		if PROFILING then profiler.Stop() end

		if test_count > 0 then
			io_write("running ", test_count, " tests took ", format_time(total), " seconds\n")
			io_write("total memory allocated: ", format_gc(total_gc), "\n")
		end
	end
end
