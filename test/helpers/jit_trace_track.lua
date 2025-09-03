--[[HOTRELOAD run_test("test/performance/parser.lua") ]]
--ANALYZE
local attach = _G.jit and _G.jit.attach
local ok, jutil = pcall(require, "jit.util")
local traceinfo = ok and jutil.traceinfo
local funcinfo = ok and jutil.funcinfo
local ok, vmdef = pcall(require, "jit.vmdef")
local ffnames = ok and vmdef.ffnames
local traceerr = ok and vmdef.traceerr
local bcnames = ok and vmdef.bcnames
--[[#local type Trace = {
	pc_lines = List<|{func = Function, depth = number, pc = number}|>,
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
local traces--[[#: Map<|number, Trace|>]] = {}
local aborted = {}

local function start(
	id--[[#: number]],
	func--[[#: Function]],
	pc--[[#: number]],
	parent_id--[[#: nil | number]],
	exit_id--[[#: nil | number]]
)
	if parent_id == nil then assert(exit_id == nil) end

	if exit_id == nil then assert(parent_id == nil) end

	-- TODO, both should be nil here
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

local function stop(id--[[#: number]], func--[[#: Function]])
	assert(traces[id])
	assert(traces[id].aborted == nil)
	traces[id].trace_info = assert(traceinfo(id), "invalid trace id: " .. id)
end

local function abort(
	id--[[#: number]],
	func--[[#: Function]],
	pc--[[#: number]],
	code--[[#: number]],
	reason--[[#: number]]
)
	assert(traces[id])
	assert(traces[id].stopped == nil)
	traces[id].trace_info = assert(traceinfo(id), "invalid trace id: " .. id)
	traces[id].aborted = {
		code = code,
		reason = reason,
	}
	table.insert(traces[id].pc_lines, {func = func, pc = pc, depth = 0})
	aborted[id] = traces[id]

	if traces[id] and traces[id].parent and traces[id].parent.children then
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

	if count > 0 then
		print("too many traces, flushing " .. count .. " traces")
	end

	traces = {}
	aborted = {}
end

local function record(tr--[[#: number]], func--[[#: Function]], pc--[[#: number]], depth--[[#: number]])
	assert(traces[tr])
	table.insert(traces[tr].pc_lines, {func = func, pc = pc, depth = depth})
end

local trace_track = {}

function trace_track.Start()
	if not attach or not funcinfo or not traceinfo then return nil end

	local traces = {}
	local aborted = {}
	local on_trace_event = function(what, tr, func, pc, otr, oex)
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
	end--[[# as jit_attach_trace]]
	attach(on_trace_event, "trace")
	local on_record_event = function(tr, func, pc, depth)
		record(tr, func, pc, depth)
	end--[[# as jit_attach_record]]
	attach(on_record_event, "record")
	return function()
		attach(on_trace_event)
		attach(on_record_event)

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
end

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

local function tostring_trace(v--[[#: Trace]], tab--[[#: nil | string]], stop_lines_only--[[#: nil | true]])
	tab = tab or ""
	local done--[[#: Map<|string, nil | true|>]] = {}
	local start_location = {}

	do
		if stop_lines_only then
			local start_depth = assert(v.pc_lines[#v.pc_lines]).depth

			for i = #v.pc_lines, 1, -1 do
				local v = assert(v.pc_lines[i])
				local line = format_func_info(funcinfo(v.func, v.pc), v.func)

				if not done[line] then
					table.insert(start_location, 1, line)
					done[line] = true

					if v.depth ~= start_depth then break end
				end
			end
		else
			for i, v in ipairs(v.pc_lines) do
				local line = format_func_info(funcinfo(v.func, v.pc), v.func)

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

local count_table = function(t--[[#: Table]])
	local count = 0

	for k, v in pairs(t) do
		count = count + 1
	end

	return count
end

function trace_track.ToStringTraceTree(traces--[[#: Map<|number, Trace|>]])
	local out = {}

	local function dump(v--[[#: Trace]], depth--[[#: number]])
		local has_one_child = v.children and count_table(v.children) == 1
		local tab = ("    "):rep(depth)

		if depth > 0 and has_one_child then depth = depth - 1 end

		table.insert(out, tab .. tostring_trace(v, tab))

		if v.children then
			for i, v in pairs(v.children) do
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

	return str
end

function trace_track.ToStringProblematicTraces(traces--[[#: Map<|number, Trace|>]], aborted--[[#: Map<|number, Trace|>]])
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

	local sorted--[[#: List<|{line = string, count = number}|>]] = {}

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

	return table.concat(out, "\n")
end

return trace_track
