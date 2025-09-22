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
local memory = require("nattlua.other.memory")
local colors = require("nattlua.cli.colors")
local BuildBaseEnvironment = require("nattlua.base_environment").BuildBaseEnvironment
local callstack = require("nattlua.other.callstack")
local system = require("nattlua.other.system")
local nl = require("nattlua")
local total_test_count = 0

function _G.test(name, cb, start, stop)
	total_test_count = total_test_count + 1

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
	profiler.StartSection("base environment")
	local _, typesystem_env = BuildBaseEnvironment()
	profiler.StopSection()

	function _G.analyze(code, expect_error, expect_warning)
		total_test_count = total_test_count + 1
		local path = callstack.get_line(2)
		local name = path:match("(test/tests/.+)") or path

		if not _G.HOTRELOAD then _G.loading_indicator() end

		_G.TEST = true
		local compiler = nl.Compiler(code, nil, nil, 3)
		profiler.StartSection("lexer")
		compiler:Lex()
		profiler.StopSection()
		profiler.StartSection("parser")
		compiler:Parse()
		profiler.StopSection()
		compiler:SetEnvironments(Table({}), typesystem_env)
		_G.TEST_GARBAGE = {}
		profiler.StartSection("analyzer")
		local ok, err = compiler:Analyze()
		profiler.StopSection()

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
	local IS_TERMINAL = system.is_tty()
	local max_path_width = 0
	local current_test_name = ""

	local function format_time(seconds)
		if seconds < 1 then
			return string.format("%4d%s", math.floor(seconds * 1000), colors.dim(" ms"))
		end

		return string.format("%4f%s", seconds, colors.dim(" s"))
	end

	local function format_gc(kb)
		return string.format("%4d%s", math.floor(kb / 1024), colors.dim(" mb"))
	end

	local spinner_chars = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧"}
	local spinner_index = 1

	local function update_test_line(status, time_str, gc_str)
		if not LOGGING then return end

		local padded_name = current_test_name .. string.rep(" ", max_path_width - #current_test_name)
		local cr = IS_TERMINAL and "\r" or ""

		if status == "RUNNING" and IS_TERMINAL then
			local spinner = spinner_chars[spinner_index]
			io_write(string.format("%s%s %s RUNNING...", cr, padded_name, spinner))
		elseif status == "DONE" then
			io_write(string.format("%s%s %s  %s\n", cr, padded_name, time_str, gc_str))
		end

		io.flush()
	end

	function _G.loading_indicator()
		if not LOGGING then return end

		if not IS_TERMINAL then return end

		-- Advance spinner and update line
		spinner_index = (spinner_index % #spinner_chars) + 1
		update_test_line("RUNNING")
	end

	-- Call this before running tests to calculate max width
	function _G.set_test_paths(tests)
		max_path_width = 0

		for _, test in ipairs(tests) do
			max_path_width = math.max(max_path_width, #test.name)
		end

		-- Add some padding for clean alignment
		max_path_width = max_path_width + 2
	end

	local total_gc = 0
	local test_file_count = 0

	function _G.begin_tests(logging, profiling, profiling_mode)
		LOGGING = logging or false
		PROFILING = profiling or false

		if _G.STARTUP_PROFILE then profiler.StopSection() end

		if PROFILING and not _G.STARTUP_PROFILE then
			profiler.Start(profiling_mode)
		end
	end

	local function run_func(func, ...)
		local gc = memory.get_usage_kb()
		local time = get_time()
		func(...)
		time = get_time() - time
		gc = memory.get_usage_kb() - gc
		-- Update final result
		update_test_line("DONE", format_time(time), format_gc(gc))
		total_gc = total_gc + gc
	end

	function _G.run_single_test(test)
		current_test_name = test.name

		-- You'll need to pass the expected test count somehow, or estimate it
		-- For now, setting to 0 means no progress counter shown
		if LOGGING then update_test_line("RUNNING") end

		if test.is_lua then
			run_func(assert(loadfile(test.path)))
		else
			run_func(analyze, assert(fs.read(test.path)))
		end

		test_file_count = test_file_count + 1
	end

	function _G.end_tests()
		local luajit_startup_time = _G.EARLY_STARTUP_TIME or 0
		local actual_total = os.clock() - luajit_startup_time

		if PROFILING then profiler.Stop() end

		if test_file_count > 0 then
			local times = profiler.GetSimpleSections()
			-- base environment time is included in startup time, so remove it
			times["startup"].total = times["startup"].total - times["base environment"].total
			local sorted = {}
			local sections_total = 0

			for name, data in pairs(times) do
				table.insert(sorted, {name = name, total = data.total})
				sections_total = sections_total + data.total
			end

			table.insert(sorted, {name = "luajit", total = luajit_startup_time})
			table.insert(sorted, {name = "untracked", total = actual_total - sections_total})

			table.sort(sorted, function(a, b)
				return a.total > b.total
			end)

			local details = {}

			for _, data in ipairs(sorted) do
				table.insert(details, colors.dim(string.format("%s: %s", data.name, format_time(data.total))))
			end

			io_write(
				"\n",
				"ran ",
				total_test_count,
				" tests in ",
				test_file_count,
				" files",
				"\n\n"
			)
			io_write(table.concat(details, colors.dim(" +\n")), "\n")
			io_write(string.format("total: %s", format_time(actual_total)), "\n")
		end
	end
end
