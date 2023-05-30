--ANALYZE
local jit = require("jit")
local jit_profiler = require("jit.profile")
local jit_vmdef = require("jit.vmdef")
local jit_util = require("jit.util")
local logf = function(f, ...)
	io.write((f):format(...))
end
local wlog = print
local logn = print
local log = io.write
local error = _G.error
local xpcall = _G.xpcall
local assert = _G.assert
local table_insert = _G.table.insert
local stringx = require("nattlua.other.string")
local mathx = require("nattlua.other.math")
local formating = require("nattlua.other.formating")
local get_time = os.clock

local function read_file(path--[[#: string]])
	local f, err = io.open(path)

	if not f then return nil, err end

	local s, err = f:read("*a")

	if not s then return nil, "empty file" end

	return s
end

local profiler = {}
profiler.sections = {}
profiler.raw_trace_aborts = {}
profiler.raw_statistical = {}
local blacklist = {
	["leaving loop in root trace"] = true,
	["error thrown or hook fed during recording"] = true,
	["too many spill slots"] = true,
}

function profiler.EnableTraceAbortLogging(b--[[#: ]]--[[boolean]] )
	if b then
		profiler.raw_trace_aborts = {}
		local i = 1
		local funcinfo = jit_util.funcinfo
		local data = profiler.raw_trace_aborts

		jit.attach(
			function(what, trace_id, func, pc, trace_error_id, trace_error_arg)
				if what == "abort" then
					data[i] = {funcinfo(func, pc), trace_error_id, trace_error_arg}
					i = i + 1
				end
			end,
			"trace"
		)
	else
		jit.attach(function() end)
	end
end

function profiler.EnableStatisticalProfiling(b--[[#: boolean]])
	i = 1

	if b then
		profiler.raw_statistical = {}
		local i = 1
		local dumpstack = jit_profiler.dumpstack
		local data = profiler.raw_statistical

		jit_profiler.start("li2", function(thread, samples, vmstate)
			data[i] = {dumpstack(thread, "pl\n", 1000), samples, vmstate}
			i = i + 1
		end)
	else
		jit_profiler.stop()
	end
end

do
	local function parse_raw_statistical_data(raw_data--[[#: List<|{string, number, string}|>]])
		local data = {}

		for i = #raw_data, 1, -1 do
			local args = assert(raw_data[i])
			local str, samples, vmstate = args[1], args[2], args[3]
			local children = {}

			for line in str:gmatch("(.-)\n") do
				local path, line_number = line:match("(.+):(%d+)")

				if not path and not line_number then
					line = line:gsub("%[builtin#(%d+)%]", function(x)
						return jit_vmdef.ffnames[tonumber(x)]
					end)
					table_insert(children, {name = line or -1, external_function = true})
				else
					table_insert(
						children,
						{path = path, line = tonumber(line_number) or -1, external_function = false}
					)
				end
			end

			local info = children[#children]
			table.remove(children, #children)
			local path = info.path or info.name
			local line = tonumber(info.line) or -1
			data[path] = data[path] or {}
			data[path][line] = data[path][line] or
				{
					total_time = 0,
					samples = 0,
					children = {},
					parents = {},
					ready = false,
					func_name = path,
					vmstate = {},
				}
			data[path][line].samples = data[path][line].samples + samples
			data[path][line].start_time = data[path][line].start_time or get_time()
			data[path][line].vmstate[vmstate] = (data[path][line].vmstate[vmstate] or 0) + 1
			local parent = data[path][line]

			for _, info in ipairs(children) do
				local path = info.path or info.name
				local line = tonumber(info.line) or -1
				data[path] = data[path] or {}
				data[path][line] = data[path][line] or
					{
						total_time = 0,
						samples = 0,
						children = {},
						parents = {},
						ready = false,
						func_name = path,
						vmstate = {},
					}
				data[path][line].samples = data[path][line].samples + samples
				data[path][line].start_time = data[path][line].start_time or get_time()
				data[path][line].vmstate[vmstate] = (data[path][line].vmstate[vmstate] or 0) + 1
				data[path][line].parents[tostring(parent)] = parent
				parent.children[tostring(data[path][line])] = data[path][line]
			end
		end

		return data
	end

	function profiler.GetBenchmark(file--[[#: nil | string]])
		local out = {}

		for path, lines in pairs(parse_raw_statistical_data(profiler.raw_statistical)) do
			if path:sub(1, 1) == "@" then path = path:sub(2) end

			if not file or path:find(file) then
				for line, data in pairs(lines) do
					line = tonumber(line) or line
					local name = "unknown(file not found)"
					local debug_info

					if data.func then
						debug_info = debug.getinfo(data.func)
						-- remove some useless fields
						debug_info.source = nil
						debug_info.short_src = nil
						debug_info.currentline = nil
						debug_info.func = nil
					end

					if data.func then
						name = ("%s(%s)"):format(data.func_name, table.concat(debug.getparams(data.func), ", "))
					else
						local full_path = path
						name = full_path .. ":" .. line
					end

					if data.section_name then
						data.section_name = data.section_name:match(".+lua/(.+)") or data.section_name
					end

					if name:find("\n", 1, true) then
						name = name:gsub("\n", "")
						name = name:sub(0, 50)
					end

					name = stringx.trim(name)
					data.path = path
					data.file_name = path:match(".+/(.+)%.") or path
					data.line = line
					data.name = name
					data.debug_info = debug_info
					data.ready = true

					if data.total_time then
						data.average_time = data.total_time / data.samples
					--data.total_time = data.average_time * data.samples
					end

					data.start_time = data.start_time or 0
					data.samples = data.samples or 0
					data.sample_duration = get_time() - data.start_time
					data.times_called = data.samples
					table_insert(out, data)
				end
			end
		end

		return out
	end

	function profiler.PrintStatistical(
		min_samples--[[#: nil | number]],
		title--[[#: nil | string]],
		file_filter--[[#: nil | string]]
	)
		min_samples = min_samples or 100
		local tr = {
			{from = "N", to = "native"},
			{from = "I", to = "interpreted"},
			{from = "G", to = "garbage collection"},
			{from = "J", to = "compiling"},
			{from = "C", to = "C code"},
		}
		local vmstate_friendly = {}

		for k, v in pairs(tr) do
			table.insert(vmstate_friendly, v.from .. " = " .. v.to)
		end

		vmstate_friendly = table.concat(vmstate_friendly, ", ")
		log(
			formating.TableToColumns(
				title or "statistical",
				profiler.GetBenchmark(file_filter),
				{
					{key = "name"},
					{
						key = "times_called",
						friendly = "percent",
						tostring = function(val, column, columns)
							return mathx.round((val / columns[#columns].val.times_called) * 100, 2)
						end,
					},
					{
						key = "vmstate",
						friendly = vmstate_friendly,
						tostring = function(vmstatemap--[[#: Map<|string, number|>]])
							local str = {}
							local total_count = 0

							for state, count in pairs(vmstatemap) do
								total_count = total_count + count
							end

							for _, tr in pairs(tr) do
								vmstatemap[tr.from] = vmstatemap[tr.from] or 0

								for state, count in pairs(vmstatemap) do
									if tr.from == state then
										--table.insert(str, string.format("%s %02d%%", state, (count / total_count) * 100))
										table.insert(str, state:rep(math.floor(count / total_count * (#vmstate_friendly - 3))))
									end
								end
							end

							return table.concat(str, "")
						end,
					},
					{
						key = "samples",
						tostring = function(val)
							return val
						end,
					},
				},
				function(a)
					return a.name and a.times_called > min_samples
				end,
				function(a, b)
					return a.times_called < b.times_called
				end
			)
		)
	end

	local blacklist = {
		["NYI: return to lower frame"] = true,
		["inner loop in root trace"] = true,
		["leaving loop in root trace"] = true,
		["blacklisted"] = true,
		["too many spill slots"] = true,
		["down-recursion, restarting"] = true,
	}

	local function parse_raw_trace_abort_data(raw_data--[[#: any]])
		local data = {}

		for i = #raw_data, 1, -1 do
			local args = raw_data[i]
			local info = args[1]
			local trace_error_id = args[2]
			local trace_error_arg = args[3]
			local reason = jit_vmdef.traceerr[trace_error_id]

			if not blacklist[reason] then
				if type(trace_error_arg) == "number" and reason:find("bytecode") then
					trace_error_arg = string.sub(jit_vmdef.bcnames, trace_error_arg * 6 + 1, trace_error_arg * 6 + 6)
					reason = reason:gsub("(%%d)", "%%s")
				end

				reason = reason:format(trace_error_arg)
				local path = info.source
				local line = info.currentline or info.linedefined
				data[path] = data[path] or {}
				data[path][line] = data[path][line] or {}
				data[path][line][reason] = (data[path][line][reason] or 0) + 1
			end
		end

		return data
	end

	function profiler.PrintTraceAborts(min_samples--[[#: nil | number]])
		min_samples = min_samples or 500
		logn(
			"trace abort reasons for functions that were sampled by the profiler more than ",
			min_samples,
			" times:"
		)
		local blacklist = {
			["NYI: return to lower frame"] = true,
			["inner loop in root trace"] = true,
			["blacklisted"] = true,
		}
		local s = parse_raw_statistical_data(profiler.raw_statistical)

		for path, lines in pairs(parse_raw_trace_abort_data(profiler.raw_trace_aborts)) do
			path = path:sub(2)

			if s[path] or not next(s) then
				local full_path = path
				local temp = {}

				for line, reasons in pairs(lines) do
					if not next(s) or s[path][line] and s[path][line].samples > min_samples then
						local str = "unknown line"
						local content, err = read_file(path)

						if content then
							local lines = stringx.split(content, "\n")
							str = lines[line] or "unknown line"
							str = "\"" .. stringx.trim(str) .. "\""
						else
							str = err
						end

						for reason, count in pairs(reasons) do
							if not blacklist[reason] then
								table_insert(temp, "\t\t" .. stringx.trim(reason) .. " (x" .. count .. ")")
								table_insert(temp, "\t\t\t" .. line .. ": " .. str)
							end
						end
					end
				end

				if #temp > 0 then
					logn("\t", full_path)
					logn(table.concat(temp, "\n"))
				end
			end
		end
	end
end

return profiler