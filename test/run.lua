return function(...)
	local path, count = ...
	local assert = _G.assert
	local loadfile = _G.loadfile
	local get_time = require("test.helpers.get_time")
	local profiler = require("test.helpers.profiler")
	local jit = _G.jit
	local ipairs = _G.ipairs
	local io = require("io")
	local io_write = _G.HOTRELOAD and function(...) end or io.write
	local pcall = _G.pcall
	local table = _G.table
	local collectgarbage = _G.collectgarbage
	local colors = require("nattlua.cli.colors")
	require("test.environment")

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

	local function run_func(func, ...)
		local time = get_time()
		local gc = collectgarbage("count")
		func(...)
		gc = collectgarbage("count") - gc
		local diff = get_time() - time
		io_write("\t", format_time(diff), " and ", format_gc(gc), "\n")
		return diff, gc
	end

	local total = 0
	local total_gc = 0
	local time_taken_before_tests = os.clock()

	if STARTUP_PROFILE then
		io_write("== startup profiling == :")
		profiler.Stop()
		io_write("== == :")
	end

	local i = 0
	function _G.loading_indicator()
		if i % 4 == 0 then 
			io_write(colors.dim("."))
			io.flush()
		end
		i = i + 1
	end

	if not _G.HOTRELOAD then profiler.Start() end

	for i = 1, tonumber(count or 1) do
		if path == "all" then path = nil end

		if path and path:sub(-4) == ".lua" then
			io_write(path, " ")
			local time = get_time()
			assert(loadfile(path))()
			io_write(" ", format_time(get_time() - time), " seconds\n")
		else
			local tests = find_tests(path)

			for _, path in ipairs(tests) do
				if path:sub(-4) == ".lua" then
					io_write((path:gsub("test/tests/", "")), "\t")
					local func = assert(loadfile(path))
					local time, gc = run_func(func)
					total = total + time
					total_gc = total_gc + gc
				end
			end

			for _, path in ipairs(tests) do
				if path:sub(-5) == ".nlua" then
					io_write((path:gsub("test/tests/", "")), "\t")
					local f = assert(io.open(path, "r"))
					local str = assert(f:read("*all"))
					f:close()
					local time, gc = run_func(analyze, str)
					total = total + time
					total_gc = total_gc + gc
				end
			end
		end
	end

	if not _G.HOTRELOAD then profiler.Stop() end

	if total > 0 then
		io_write("all tests together took ", format_time(total), " seconds\n")
		io_write(
			"startup time (from program start to first tests run) took ",
			format_time(time_taken_before_tests),
			" seconds\n"
		)
		io_write("total memory allocated during tests: ", format_gc(total_gc), "\n")
	end
--[=[
if ALL_NODES then

	for _, nodes in pairs(ALL_NODES) do
		for type_kind, fields in pairs(nodes) do
			for field, types in pairs(fields) do
				if field ~= "tokens" then
					local count = 0
					for type in pairs(types) do
						count = count + 1
					end
					if count == 1 then
						fields[field] = next(types)
					end
				end
			end
			fields.environment = nil
			fields.Code = nil
			fields.code_start = nil
			fields.code_stop = nil
			fields.type = nil
			fields.kind = nil
			fields.parent = nil
			fields.inferred_types = nil
		end
	end

	
	local lua = "local nodes = {\n"
	for type, nodes in pairs(ALL_NODES) do
		lua = lua .. type .. " = {\n"
		for kind, node in pairs(nodes) do
			lua = lua .. "[\"" .. kind .. "\"] = function(type, kind, environment, code, code_start, code_stop, parent)\n"
			lua = lua .. "\t return {\n"
			lua = lua .. "\ttype = type,\n"
			lua = lua .. "\tkind = kind,\n"
			lua = lua .. "\tenvironment = environment,\n"
			lua = lua .. "\tcode = code,\n"
			lua = lua .. "\tcode_start = code_start,\n"
			lua = lua .. "\tcode_stop = code_stop,\n"
			lua = lua .. "\tparent = parent,\n"
			for k,v in pairs(node) do
				if k ~= "tokens" then
					lua = lua .. "\t" .. k .. " = false,\n"
				end
			end 
			lua = lua .. "\ttokens = {\n"
			for k,v in pairs(node.tokens) do
				lua = lua .. "\t[\"" .. k .. "\"] = false,\n"
			end 
			lua = lua .. "},\n"
			lua = lua .. "}\n"
			lua = lua .. "end,\n"
		end
		lua = lua .. "},\n"
	end
	lua = lua .. "}\n"
	print(lua)
end
]=]
end
