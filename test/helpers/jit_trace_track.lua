--[[HOTRELOAD
os.execute("luajit nattlua.lua profile trace")
]]
--ANALYZE
local jutil = require("jit.util")
local vmdef = require("jit.vmdef")
local get_mcode_calls = require("test.helpers.jit_mcode_stats")
local assert = _G.assert
local table_insert = _G.table.insert
local attach = _G.jit and _G.jit.attach
local traceinfo = jutil.traceinfo
local funcinfo = jutil.funcinfo
local ffnames = vmdef.ffnames
local traceerr = vmdef.traceerr
local bcnames = vmdef.bcnames

local function format_error(err--[[#: number]], arg--[[#: number | nil]])
	local fmt = traceerr[err]

	if not fmt then return "unknown error: " .. err end

	if not arg then return fmt end

	if fmt:sub(1, #"NYI: bytecode") == "NYI: bytecode" then
		local oidx = 6 * arg
		arg = bcnames:sub(oidx + 1, oidx + 6)
		fmt = "NYI bytecode %s"
	end

	return string.format(fmt, arg)
end

local function create_warn_log(interval)
	local i = 0
	local last_time = 0
	return function()
		i = i + 1

		if last_time < os.clock() then
			last_time = os.clock() + interval
			return i, interval
		end

		return false
	end
end

--[[#local type Trace = {
	pc_lines = List<|{func = Function, depth = number, pc = number}|>,
	lines = List<|{line = string, depth = number}|>,
	id = number,
	exit_id = number,
	parent_id = number,
	parent = nil | self,
	DEAD = nil | true,
	stopped = nil | true,
	aborted = nil | {code = number, reason = number},
	children = nil | Map<|number, self|>,
	trace_info = ReturnType<|traceinfo|>[1] ~ nil,
}]]

local function format_func_info(fi--[[#: ReturnType<|funcinfo|>[1] ]], func--[[#: Function]])
	if fi.loc then
		local source = fi.source

		if source:sub(1, 1) == "@" then source = source:sub(2) end

		if source:sub(1, 2) == "./" then source = source:sub(3) end

		return source .. ":" .. fi.currentline
	elseif fi.ffid then
		return ffnames[fi.ffid]
	elseif fi.addr then
		return string.format("C:%x, %s", fi.addr, tostring(func))
	else
		return "(?)"
	end
end

local trace_track = {}

function trace_track.Start()
	if not attach or not funcinfo or not traceinfo then return nil end

	local should_warn_mcode = create_warn_log(2)
	local should_warn_abort = create_warn_log(8)
	local traces--[[#: Map<|number, Trace|>]] = {}
	local aborted = {}
	local trace_count = 0

	local function start(
		id--[[#: number]],
		func--[[#: Function]],
		pc--[[#: number]],
		parent_id--[[#: nil | number]],
		exit_id--[[#: nil | number]]
	)
		-- TODO, both should be nil here
		local tr = {
			pc_lines = {{func = func, pc = pc, depth = 0}},
			id = id,
			exit_id = exit_id,
			parent_id = parent_id,
		}
		local parent = parent_id and traces[parent_id]

		if parent then
			tr.parent = parent
			parent.children = parent.children or {}
			parent.children[id] = tr
		else
			tr.parent_id = parent_id
		end

		traces[id] = tr
		trace_count = trace_count + 1
	end

	local function stop(id--[[#: number]], func--[[#: Function]])
		local trace = assert(traces[id])
		assert(trace.aborted == nil)
		trace.trace_info = assert(traceinfo(id), "invalid trace id: " .. id)
	end

	local function abort(
		id--[[#: number]],
		func--[[#: Function]],
		pc--[[#: number]],
		code--[[#: number]],
		reason--[[#: number]]
	)
		local trace = assert(traces[id])
		assert(trace.stopped == nil)
		trace.trace_info = assert(traceinfo(id), "invalid trace id: " .. id)
		trace.aborted = {
			code = code,
			reason = reason,
		}
		table_insert(trace.pc_lines, {func = func, pc = pc, depth = 0})
		aborted[id] = trace

		if trace.parent and trace.parent.children then
			trace.parent.children[id] = nil
		end

		trace.DEAD = true
		traces[id] = nil
		trace_count = trace_count - 1

		-- mcode allocation issues should be logged right away
		if code == 27 then
			local x, interval = should_warn_mcode()

			if x then
				io.write(
					format_error(code, reason),
					x == 0 and "" or " [" .. x .. " times the last " .. interval .. " seconds]",
					"\n"
				)
			end
		end
	end

	local function flush()
		if trace_count > 0 then
			local x, interval = should_warn_abort()

			if x then
				io.write(
					"flushing ",
					trace_count,
					" traces, ",
					(x == 0 and "" or "[" .. x .. " times the last " .. interval .. " seconds]"),
					"\n"
				)
			end
		end

		traces = {}
		aborted = {}
		trace_count = 0
	end

	local function record(tr--[[#: number]], func--[[#: Function]], pc--[[#: number]], depth--[[#: number]])
		assert(traces[tr])
		table_insert(traces[tr].pc_lines, {func = func, pc = pc, depth = depth})
	end

	local on_trace_event--[[#: jit_attach_trace]] = function(what, tr, func, pc, otr, oex)
		if what == "start" then
			start(tr, func, pc, otr, oex)
		elseif what == "stop" then
			stop(tr, func)
		elseif what == "abort" then
			abort(tr, func, pc, otr, oex)
		elseif what == "flush" then
			flush()
		else
			error("unknown trace event " .. what)
		end
	end
	attach(on_trace_event, "trace")
	local on_record_event--[[#: jit_attach_record]] = function(tr, func, pc, depth)
		record(tr, func, pc, depth)
	end
	attach(on_record_event, "record")
	return function()
		attach(on_trace_event)
		attach(on_record_event)

		for what, traces in pairs({traces = traces, aborted = aborted}) do
			for k, v in pairs(traces) do
				do
					if what == "aborted" then
						assert(v.stopped == nil)
						assert(v.DEAD)
					elseif what == "traces" then
						assert(v.aborted == nil)
					end
				end

				if v.children then
					local new = {}

					for k, v in pairs(v.children) do
						table.insert(new, v)
					end

					table.sort(new, function(a, b)
						return a.exit_id < b.exit_id
					end)

					v.children = new
				end
			end
		end

		local cache = {}

		local function get_code(loc--[[#: string]])
			if cache[loc] ~= nil then return cache[loc] end

			local start, stop = loc:find(":")

			if not start then
				cache[loc] = false
				return nil
			end

			local path = loc:sub(1, start - 1)
			local line = tonumber(loc:sub(stop + 1))
			local f = io.open(path, "r")

			if not f then
				cache[loc] = false
				return nil
			end

			local i = 1

			for line_str in f:lines() do
				if i == line then
					f:close()
					cache[loc] = line_str:match("^%s*(.-)%s*$") or line_str
					return cache[loc]
				end

				i = i + 1
			end

			f:close()
			cache[loc] = false
			return nil
		end

		local function unpack_lines(trace--[[#: Trace]])
			local lines = {}
			local done = {}
			local lines_i = 1

			for i, pc_line in ipairs(trace.pc_lines) do
				local info = funcinfo(pc_line.func, pc_line.pc)
				local line = format_func_info(info, pc_line.func)

				if not done[line] then
					done[line] = true
					lines[lines_i] = {
						line = line,
						code = get_code(line),
						depth = pc_line.depth,
						is_path = info.loc ~= nil,
					}
					lines_i = lines_i + 1
				end
			end

			trace.lines = lines
		end

		-- remove aborted traces that were eventually succesfully traced
		for id, trace in pairs(aborted) do
			if traces[id] then aborted[id] = nil end

			unpack_lines(trace)
		end

		-- remove that were never stopped or aborted
		for id, trace in pairs(traces) do
			if not trace.trace_info then traces[id] = nil end

			unpack_lines(trace)
		end

		local traces_sorted = {}
		local aborted_sorted = {}

		for _, trace in pairs(traces) do
			table_insert(traces_sorted, trace)
		end

		for _, trace in pairs(aborted) do
			table_insert(aborted_sorted, trace)
		end

		table.sort(traces_sorted, function(a, b)
			return a.id < b.id
		end)

		table.sort(aborted_sorted, function(a, b)
			return a.id < b.id
		end)

		return traces_sorted, aborted_sorted
	end
end

local function tostring_trace_lines_end(trace--[[#: Trace]], line_prefix--[[#: nil | string]])
	line_prefix = line_prefix or ""
	local lines = {}
	local start_depth = assert(trace.lines[#trace.lines]).depth

	for i = #trace.lines, 1, -1 do
		local line = trace.lines[i]
		table.insert(lines, 1, line_prefix .. line.line)

		if line.depth ~= start_depth then break end
	end

	return table.concat(lines, "\n")
end

local function tostring_trace_lines_full(trace--[[#: Trace]], tab--[[#: nil | string]], line_prefix--[[#: nil | string]])
	line_prefix = line_prefix or ""
	tab = tab or ""
	local lines = {}

	for i, line in ipairs(trace.lines) do
		lines[i] = line_prefix .. (i == 1 and "" or tab) .. (" "):rep(line.depth) .. line.line
	end

	local max_len = 0

	for i, line in ipairs(lines) do
		if #line > max_len then max_len = #line end
	end

	for i, line in ipairs(lines) do
		if trace.lines[i].code then
			lines[i] = lines[i] .. (" "):rep(max_len - #line + 2) .. " -- " .. trace.lines[i].code
		end
	end

	return table.concat(lines, "\n")
end

local function tostring_trace_lines_flow(trace--[[#: Trace]], line_prefix--[[#: nil | string]])
	line_prefix = line_prefix or ""
	local out = {}
	local depths = {}

	for i, line in ipairs(trace.lines) do
		if line.is_path then
			depths[line.depth] = depths[line.depth] or {}
			table.insert(depths[line.depth], {i = i, line = line.line})
		end
	end

	local sorted = {}

	for depth, lines in pairs(depths) do
		table.insert(sorted, {line = lines[#lines]})
	end

	table.sort(sorted, function(a, b)
		return a.line.i < b.line.i
	end)

	for i, v in ipairs(sorted) do
		table.insert(out, line_prefix .. v.line.line)
	end

	return table.concat(out, "\n")
end

local function tostring_trace(trace--[[#: Trace]], traces--[[#: Map<|number, Trace|>]])
	local str = ""
	local link = trace.trace_info.linktype

	if link == "root" then
		local link_node = traces[trace.trace_info.link]

		if link_node then
			link = "link > [" .. link_node.id .. "]"
		else
			link = "link > [" .. trace.trace_info.link .. "?]"
		end
	end

	if trace.aborted then
		str = str .. "ABORTED: " .. format_error(trace.aborted.code, trace.aborted.reason)
	else
		str = str .. link
	end

	return str
end

local count_table = function(t--[[#: Table]])
	local count = 0

	for k, v in pairs(t) do
		count = count + 1
	end

	return count
end

function trace_track.ToStringTraceTree(traces--[[#: Map<|number, Trace|>]])
	local out = {}

	local function dump(trace--[[#: Trace]], depth--[[#: number]])
		local has_one_child = trace.children and count_table(trace.children) == 1
		local tab = ("    "):rep(depth)

		if depth > 0 and has_one_child then depth = depth - 1 end

		table.insert(
			out,
			tab .. tostring_trace(trace, traces) .. ":\n" .. tostring_trace_lines_full(trace, tab)
		)

		if trace.children then
			for i, child in pairs(trace.children) do
				dump(child, depth + 1)
			end
		end
	end

	for _, trace in ipairs(traces) do
		if not trace.parent then dump(trace, 0) end
	end

	local str = table.concat(out, "\n")

	do -- remove trace ids only shown once to reduce clutter
		local found_ids = {}

		str:gsub("%[%d+%] ", function(s)
			found_ids[s] = (found_ids[s] or 0) + 1
		end)

		str = str:gsub("%[%d+%] ", function(s)
			if found_ids[s] == 1 then return "" end
		end)
	end

	return str
end

function trace_track.ToStringTraceStatistics(traces--[[#: Map<|number, Trace|>]], aborted--[[#: Map<|number, Trace|>]])
	local lines = {}

	local function add(fmt, ...)
		table.insert(lines, string.format(fmt, ...))
	end

	local total = 0
	local stitched = 0
	local total_exits = 0
	local root_traces = 0
	local max_depth = 0
	local max_exits = 0
	local total_ir_ins = 0 -- Changed to IR instructions
	local total_constants = 0 -- Also track constants
	local total_mcode = 0 -- Also track machine code size
	-- Track link types
	local link_types = {}
	-- Track exit distribution
	local high_exit_traces = 0
	local very_high_exit_traces = 0
	local found = {}

	for _, trace in ipairs(traces) do
		if false then -- too complex and noisy
			for func, count in pairs(get_mcode_calls(trace)) do
				found[func] = (found[func] or 0) + count
			end
		end

		total = total + 1
		local nexit = trace.trace_info.nexit or 0
		total_exits = total_exits + nexit
		-- Track IR instructions and constants
		local nins = trace.trace_info.nins or 0
		local nk = trace.trace_info.nk or 0
		total_ir_ins = total_ir_ins + nins
		total_constants = total_constants + nk
		local mcode, addr, loop = jutil.tracemc(trace.id)
		total_mcode = total_mcode + #mcode

		-- Track max exits
		if nexit > max_exits then max_exits = nexit end

		-- Count high exit traces
		if nexit > 100 then high_exit_traces = high_exit_traces + 1 end

		if nexit > 1000 then very_high_exit_traces = very_high_exit_traces + 1 end

		-- Track link types
		local linktype = trace.trace_info.linktype or "unknown"
		link_types[linktype] = (link_types[linktype] or 0) + 1

		-- Count stitched traces
		if linktype == "stitch" then stitched = stitched + 1 end

		-- Count root traces (no parent)
		if not trace.parent then root_traces = root_traces + 1 end

		-- Track depth
		local depth = 0
		local current = trace

		while current.parent do
			depth = depth + 1
			current = current.parent
		end

		if depth > max_depth then max_depth = depth end
	end

	-- Count aborted traces
	local aborted_count = 0
	local aborted_reasons = {}

	for _, trace in ipairs(aborted) do
		aborted_count = aborted_count + 1

		if trace.aborted then
			local reason = format_error(trace.aborted.code, trace.aborted.reason)
			aborted_reasons[reason] = (aborted_reasons[reason] or 0) + 1
		end
	end

	-- Show found functions in disassembly
	if next(found) then
		local found_list = {}

		for k, v in pairs(found) do
			table.insert(found_list, {name = k, count = v})
		end

		table.sort(found_list, function(a, b)
			return a.count > b.count
		end)

		if #found_list > 0 then
			add("=== Disassembled Functions ===")

			for i, v in ipairs(found_list) do
				add("%s: %d", v.name, v.count)
			end
		end
	end

	-- Build output
	add("=== Trace Statistics ===")
	add("Total traces: %d", total)
	add("Root traces: %d", root_traces)
	add("Total exits: %d", total_exits)
	add("Total IR instructions: %d", total_ir_ins)
	add("Total constants: %d", total_constants)
	add("Total machine code size: %d bytes", total_mcode)

	if total > 0 then
		add("Average exits per trace: %.1f", total_exits / total)
		add("Average IR instructions per trace: %.1f", total_ir_ins / total)
		add("Average constants per trace: %.1f", total_constants / total)
		add("Max exits in a trace: %d", max_exits)
	end

	add("\n=== Link Types ===")

	for linktype, count in pairs(link_types) do
		if total > 0 then
			add("%s: %d (%.1f%%)", linktype, count, (count / total) * 100)
		else
			add("%s: %d", linktype, count)
		end
	end

	if high_exit_traces > 0 or very_high_exit_traces > 0 then
		add("\n=== Exit Distribution ===")

		if high_exit_traces > 0 then
			add("Traces with >100 exits: %d", high_exit_traces)
		end

		if very_high_exit_traces > 0 then
			add("Traces with >1000 exits: %d", very_high_exit_traces)
		end
	end

	if aborted_count > 0 then
		add("\n=== Aborted Traces ===")
		add("Total aborted: %d", aborted_count)

		for reason, count in pairs(aborted_reasons) do
			add("  %s: %d", reason, count)
		end
	end

	add("\n=== Trace Depth ===")
	add("Max trace depth: %d", max_depth)
	return table.concat(lines, "\n")
end

function trace_track.ToStringProblematicTraces(traces--[[#: Map<|number, Trace|>]], aborted--[[#: Map<|number, Trace|>]])
	local map = {}

	for _, trace in ipairs(traces) do
		local linktype = trace.trace_info.linktype
		local nexit = trace.trace_info.nexit or 0
		-- Check for various problematic patterns
		local reason
		local stop_lines_only = false

		if linktype == "stitch" then
			-- Always problematic - should have been stitched
			stop_lines_only = true
		elseif linktype == "interpreter" and nexit > 100 then
			-- Hot exit to interpreter
			reason = "HOT_INTERP(exits:" .. nexit .. ")"
		elseif linktype == "none" then
			-- No continuation
			reason = "NO_LINK"
		elseif linktype == "return" and nexit > 100 then
			-- Frequently returning
			stop_lines_only = true -- limit to 10 lines
			reason = "HOT_RETURN(exits:" .. nexit .. ")"
		elseif linktype == "loop" and nexit > 1000 then
			-- Loop exiting frequently
			reason = "UNSTABLE_LOOP(exits:" .. nexit .. ")"
		end

		if reason then
			local res = tostring_trace(trace, traces) .. " - " .. reason .. ":\n" .. tostring_trace_lines_end(trace, " ")
			map[res] = (map[res] or 0) + 1
		end
	end

	if false then -- too complex and noisy
		for _, trace in ipairs(traces) do
			local found = get_mcode_calls(trace)

			if next(found) then
				local calls = {}

				for func, count in pairs(found) do
					table.insert(calls, func .. (count > 1 and ("(x" .. count .. ")") or ""))
				end

				local res = tostring_trace(trace, traces) .. " - HOT_CALL(" .. table.concat(calls, ", ") .. "):\n" .. tostring_trace_lines_full(trace, " ")
				map[res] = (map[res] or 0) + 1
			end
		end
	end

	for _, trace in ipairs(aborted) do
		local res = tostring_trace(trace, traces) .. ":\n" .. tostring_trace_lines_end(trace, " ")
		map[res] = (map[res] or 0) + 1
	end

	local sorted--[[#: List<|{line = string, count = number}|>]] = {}

	for k, v in pairs(map) do
		table.insert(sorted, {line = k, count = v})
	end

	table.sort(sorted, function(a, b)
		return a.count < b.count
	end)

	local out = {}

	for i, v in ipairs(sorted) do
		out[i] = v.line .. (v.count > 1 and (" (x" .. v.count .. ")") or "") .. "\n"
	end

	return table.concat(out, "\n")
end

function trace_track.ToStringTraceInfo(traces--[[#: Map<|number, Trace|>]], aborted--[[#: Map<|number, Trace|>]])
	local str = ""
	str = str .. trace_track.ToStringTraceStatistics(traces, aborted) .. "\n"
	local problematic = trace_track.ToStringProblematicTraces(traces, aborted)

	if #problematic > 0 then
		str = str .. "\nluajit traces that were aborted and stitched:\n"
		str = str .. problematic .. "\n"
	else
		str = str .. "\nno problematic traces found\n"
	end

	return str
end

return trace_track
