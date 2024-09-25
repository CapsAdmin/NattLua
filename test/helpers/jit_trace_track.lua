local jit = require("jit")
local jutil = require("jit.util")
local jbc = require("jit.bc")
local vmdef = require("jit.vmdef")
local traces = {}
local aborted = {}

local function start(id, func, pc, parent_id, exit_id)
	if parent_id == nil then assert(exit_id == nil) end

	if exit_id == nil then assert(parent_id == nil) end

	local tr = {
		pc_lines = {{func = func, pc = pc, depth = 0}},
		id = id,
		exit_id = exit_id,
		parent_id = parent_id,
	}

	if parent_id then
		if traces[parent_id] then
			tr.parent = traces[parent_id]
			traces[parent_id].children = traces[parent_id].children or {}
			traces[parent_id].children[id] = tr
		else
			tr.parent_id = parent_id
		end
	end

	traces[id] = tr
end

local function stop(id, func)
	assert(traces[id].aborted == nil)
	traces[id].trace_info = jutil.traceinfo(id)
end

local function abort(id, func, pc, code, reason)
	assert(traces[id].stopped == nil)
	traces[id].trace_info = jutil.traceinfo(id)
	traces[id].aborted = {
		code = code,
		reason = reason,
	}
	table.insert(traces[id].pc_lines, {func = func, pc = pc, depth = 0})
	aborted[id] = traces[id]

	if traces[id] and traces[id].parent then
		traces[id].parent.children[id] = nil
	end

	if traces[id] then traces[id].DEAD = true end

	traces[id] = nil
end

local function flush()
	local count = 0

	for i, v in pairs(traces) do
		count = count + 1
	end

	print("too many traces, flushing " .. count .. " traces")
	traces = {}
	aborted = {}
end

local function record(tr, func, pc, depth)
	table.insert(traces[tr].pc_lines, {func = func, pc = pc, depth = depth})
end

local trace_track = {}
local on_trace_event = nil
local on_record_event = nil

function trace_track.Start()
	assert(on_trace_event == nil)
	traces = {}
	aborted = {}
	on_trace_event = function(what, tr, func, pc, otr, oex)
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
	on_record_event = function(tr, func, pc, depth)
		record(tr, func, pc, depth)
	end
	jit.attach(on_trace_event, "trace")
	jit.attach(on_record_event, "record")
end

function trace_track.Stop()
	assert(on_trace_event)
	jit.attach(on_trace_event)
	jit.attach(on_record_event)
	on_trace_event = nil

	for what, traces in pairs({traces = traces, aborted = aborted}) do
		for k, v in pairs(traces) do
			if not v.pc_lines then table.print(v) end

			assert(v.pc_lines)

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

	-- remove aborted traces that were eventually succesfully traced
	for id in pairs(aborted) do
		if traces[id] then aborted[id] = nil end
	end

	return traces, aborted
end

local function find_function() end

local function format_func_info(fi, func)
	if fi.loc then
		local source = fi.source

		if source:sub(1, 1) == "@" then source = source:sub(2) end

		if source:sub(1, 2) == "./" then
			source = source:sub(3)
		end

		return source .. ":" .. fi.currentline
	elseif fi.ffid then
		return vmdef.ffnames[fi.ffid]
	elseif fi.addr then
		return string.format("C:%x, %s", fi.addr, tostring(func))
	else
		return "(?)"
	end
end

local function format_error(err, arg)
	local fmt = vmdef.traceerr[err]

	if not fmt then return "unknown error: " .. err end

	if not arg then return fmt end

	if fmt:sub(1, #"NYI: bytecode") == "NYI: bytecode" then
		local oidx = 6 * arg
		arg = vmdef.bcnames:sub(oidx + 1, oidx + 6)
		fmt = "NYI bytecode %s"
	end

	return string.format(fmt, arg)
end

local function tostring_trace(v, tab, stop_lines_only)
	tab = tab or ""
	local done = {}
	local start_location = {}

	do
		if stop_lines_only then
			local start_depth = v.pc_lines[#v.pc_lines].depth

			for i = #v.pc_lines, 1, -1 do
				local v = v.pc_lines[i]
				local line = format_func_info(jutil.funcinfo(v.func, v.pc), v.func)

				if not done[line] then
					table.insert(start_location, 1, line)
					done[line] = true

					if v.depth ~= start_depth then break end
				end
			end
		else
			for i, v in ipairs(v.pc_lines) do
				local line = format_func_info(jutil.funcinfo(v.func, v.pc), v.func)

				if not done[line] then
					table.insert(start_location, (i == 1 and "" or tab) .. (" "):rep(v.depth) .. line)
					done[line] = true
				end
			end
		end

		start_location = table.concat(start_location, "\n")
	end

	local str = ""

	if not stop_lines_only then str = str .. "[" .. v.id .. "] " end

	local link = v.trace_info.linktype

	if link == "root" then
		local link_node = traces[v.trace_info.link]

		if link_node then
			link = "link > [" .. link_node.id .. "]"
		else
			link = "link > [" .. v.trace_info.link .. "?]"
		end
	end

	str = str .. link
	str = str .. " - "

	if v.aborted then
		str = str .. "ABORTED: " .. format_error(v.aborted.code, v.aborted.reason)
		str = str .. " - "
	end

	str = str .. start_location
	return str
end

function trace_track.DumpTraceTree(traces)
	local out = {}

	local function dump(v, depth)
		local has_one_child = v.children and #v.children == 1
		local tab = ("    "):rep(depth)

		if depth > 0 and has_one_child then depth = depth - 1 end

		table.insert(out, tab .. tostring_trace(v, tab))

		if v.children then
			for i, v in ipairs(v.children) do
				dump(v, depth + 1)
			end
		end
	end

	for k, v in pairs(traces) do
		if not v.parent then dump(v, 0) end
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

	print(str)
end

function trace_track.DumpProblematicTraces(traces, aborted)
	local map = {}

	for k, v in pairs(traces) do
		if v.trace_info.linktype == "stitch" then
			local res = tostring_trace(v, nil, true)
			map[res] = (map[res] or 0) + 1
		end
	end

	for k, v in pairs(aborted) do
		local res = tostring_trace(v, nil, true)
		map[res] = (map[res] or 0) + 1
	end

	local sorted = {}

	for k, v in pairs(map) do
		table.insert(sorted, {line = k, count = v})
	end

	table.sort(sorted, function(a, b)
		return a.count < b.count
	end)

	local out = {}

	for i, v in ipairs(sorted) do
		out[i] = "x" .. v.count .. " :" .. v.line
	end

	print(table.concat(out, "\n"))
end

return trace_track
