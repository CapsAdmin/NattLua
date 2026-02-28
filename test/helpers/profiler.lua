--ANALYZE
local jutil = require("jit.util")
local vmdef = require("jit.vmdef")
local jprofile = require("jit.profile")
local jit = _G.jit
local table_concat = _G.table.concat
local table_insert = _G.table.insert
local table_remove = _G.table.remove
local string_format = _G.string.format
local time_function--[[#: function=()>(number) | nil]] = nil

local function get_time_function()
	local has_ffi, ffi = pcall(require, "ffi")

	if not has_ffi then return os.clock end

	local tonumber = _G.tonumber

	if ffi.os == "OSX" then
		ffi.cdef([[
			uint64_t clock_gettime_nsec_np(int clock_id);
		]])
		local C = ffi.C
		local CLOCK_UPTIME_RAW = 8
		local start_time = C.clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
		return function()
			local current_time = C.clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
			return tonumber(current_time - start_time) / 1000000000.0
		end
	elseif ffi.os == "Windows" then
		ffi.cdef([[
			int QueryPerformanceFrequency(int64_t *lpFrequency);
			int QueryPerformanceCounter(int64_t *lpPerformanceCount);
		]])
		local q = ffi.new("int64_t[1]")
		ffi.C.QueryPerformanceFrequency(q)
		local freq = tonumber(q[0])
		local start_time = ffi.new("int64_t[1]")
		ffi.C.QueryPerformanceCounter(start_time)
		return function()
			local time = ffi.new("int64_t[1]")
			ffi.C.QueryPerformanceCounter(time)
			time[0] = time[0] - start_time[0]
			return tonumber(time[0]) / freq
		end
	else
		ffi.cdef([[
			int clock_gettime(int clock_id, void *tp);
		]])
		local ts = ffi.new("struct { long int tv_sec; long int tv_nsec; }[1]")
		local func = ffi.C.clock_gettime
		return function()
			func(1, ts)
			return tonumber(ts[0].tv_sec) + tonumber(ts[0].tv_nsec) * 0.000000001
		end
	end
end

local function format_error(err--[[#: number]], arg--[[#: any]])--[[#: string]]
	local fmt = vmdef.traceerr[err]

	if not fmt then return "unknown error: " .. err end

	if not arg then return fmt end

	if fmt:sub(1, #"NYI: bytecode") == "NYI: bytecode" then
		local oidx = 6 * arg
		arg = vmdef.bcnames:sub(oidx + 1, oidx + 6):gsub("%s+$", "")
		fmt = "NYI bytecode %s"
	end

	return string_format(fmt, arg)
end

local function create_warn_log(interval--[[#: number]])--[[#: function=()>(number | false, number | nil)]]
	local i = 0
	local last_time--[[#: number]] = 0
	return function()
		i = i + 1

		if last_time < os.clock() then
			last_time = os.clock() + interval
			return i, interval
		end

		return false
	end
end

local function format_func_info(fi--[[#: jit_util_funcinfo]], func--[[#: AnyFunction]])--[[#: string]]
	if fi.loc and fi.currentline ~= 0 then
		local source = fi.source

		if source:sub(1, 1) == "@" then source = source:sub(2) end

		if source:sub(1, 2) == "./" then source = source:sub(3) end

		return source .. ":" .. fi.currentline
	elseif fi.ffid then
		return vmdef.ffnames[fi.ffid]--[[# as string]]
	elseif fi.addr then
		return string_format("C:%x, %s", fi.addr, tostring(func))
	else
		return "(?)"
	end
end

local function json_string(s--[[#: string]])
	s = s:gsub("\\", "\\\\")
	s = s:gsub("\"", "\\\"")
	s = s:gsub("\n", "\\n")
	s = s:gsub("\r", "\\r")
	s = s:gsub("\t", "\\t")
	return "\"" .. s .. "\""
end

-- --- Profiler ---
local HTML_TEMPLATE--[[#: string]] -- forward declaration, assigned at bottom of file
local Profiler = {}
Profiler.__index = Profiler
--[[#type TEvent = {
		type = "sample",
		time = number | nil,
		stack = string,
		sample_count = number,
		vm_state = string,
		section_path = string,
	} | {
		type = "section_start" | "section_end",
		time = number | nil,
		name = string,
		section_path = string,
	} | {
		type = "trace_start",
		time = number | nil,
		id = number,
		parent_id = number | nil,
		exit_id = number | nil,
		depth = number,
		func_info = string,
	} | {
		type = "trace_stop",
		time = number | nil,
		id = number,
		func_info = string,
		linktype = string | nil,
		link_id = number | nil,
		ir_count = number | nil,
		exit_count = number | nil,
	} | {
		type = "trace_abort",
		time = number | nil,
		id = number,
		abort_code = number | nil,
		abort_reason = string,
		func_info = string,
	} | {
		type = "trace_flush",
		time = number | nil,
	}]]
--[[#-- --- Type Definitions ---
type Profiler.@SelfArgument = {
	_id = string,
	_path = string,
	_file_url = string,
	_mode = string,
	_depth = number,
	_sampling_rate = number,
	_flush_interval = number,
	_get_time = function=()>(number),
	_time_start = number,
	_running = boolean,
	_events = List<|TEvent|>,
	_event_count = number,
	_last_flush_time = number,
	_strings = List<|string|>,
	_string_lookup = Map<|string, number|>,
	_string_count = number,
	_strings_flushed = number,
	_section_stack = List<|string|>,
	_section_path = string,
	_traces = List<|{id = number, parent_id = number | nil, exit_id = number | nil, depth = number}|>,
	_trace_count = number,
	_trace_generation = number,
	_aborted = List<|boolean|>,
	_should_warn_mcode = function=()>(number | false, number | nil),
	_should_warn_abort = function=()>(number | false, number | nil),
	_last_flushed_idx = number,
	_file = File | nil,
	_trace_event_fn = jit_attach_trace | nil,
	_trace_event_safe_fn = jit_attach_trace | nil,
	@MetaTable = Profiler,
}]]
--[[#local type TProfile = Profiler.@SelfArgument]]

-- --- Event accumulation ---
function Profiler:EmitEvent(event--[[#: TEvent]])
	event.time = self._get_time()
	local idx = self._event_count + 1
	self._events[idx] = event
	self._event_count = idx
end

-- --- Section tracking ---
function Profiler:StartSection(name--[[#: string]])
	if not self._running then return end

	-- Event section tracking
	table_insert(self._section_stack, name)
	self._section_path = table_concat(self._section_stack, " > ")
	self:EmitEvent({type = "section_start", name = name, section_path = self._section_path})
end

function Profiler:StopSection()
	if not self._running then return end

	local name = self._section_stack[#self._section_stack]

	if #self._section_stack > 0 then
		self._section_stack[#self._section_stack] = nil
		self._section_path = table_concat(self._section_stack, " > ")
	end

	self:EmitEvent({type = "section_end", name = name, section_path = self._section_path})
end

do
	local function on_trace_start(
		self--[[#: TProfile]],
		id--[[#: number]],
		func--[[#: AnyFunction]],
		pc--[[#: number]],
		parent_id--[[#: number | nil]],
		exit_id--[[#: number | string | nil]]
	)
		local fi = jutil.funcinfo(func, pc)
		local loc = format_func_info(fi, func)
		local depth = 0
		local parent = parent_id and self._traces[parent_id]

		if parent then depth = (parent.depth or 0) + 1 end

		self._traces[id] = {id = id, parent_id = parent_id, exit_id = exit_id, depth = depth}
		self._trace_count = self._trace_count + 1
		self:EmitEvent(
			{
				type = "trace_start",
				id = id,
				generation = self._trace_generation,
				parent_id = parent_id,
				exit_id = exit_id,
				depth = depth,
				func_info = loc,
			}
		)
	end

	local function on_trace_stop(self--[[#: TProfile]], id--[[#: number]], func--[[#: AnyFunction]])
		local trace = self._traces[id]

		if not trace then return end

		local ti = jutil.traceinfo(id)
		local fi = jutil.funcinfo(func)
		local loc = format_func_info(fi, func)
		self:EmitEvent(
			{
				type = "trace_stop",
				id = id,
				generation = self._trace_generation,
				func_info = loc,
				linktype = ti and ti.linktype or nil,
				link_id = ti and ti.link or nil,
				ir_count = ti and ti.nins or nil,
				exit_count = ti and ti.nexit or nil,
			}
		)
	end

	local function on_trace_abort(
		self--[[#: TProfile]],
		id--[[#: number]],
		func--[[#: AnyFunction]],
		pc--[[#: number]],
		code--[[#: number]],
		reason--[[#: number | string]]
	)
		local trace = self._traces[id]

		if not trace then return end

		local fi = jutil.funcinfo(func, pc)
		local loc = format_func_info(fi, func)
		self._aborted[id] = true
		self._traces[id] = nil
		self._trace_count = self._trace_count - 1
		self:EmitEvent(
			{
				type = "trace_abort",
				id = id,
				generation = self._trace_generation,
				abort_code = code,
				abort_reason = format_error(code, reason),
				func_info = loc,
			}
		)

		if code == 27 then
			local x, interval = self._should_warn_mcode()

			if x and interval then
				io.write(
					format_error(code, reason),
					x == 0 and "" or " [" .. x .. " times the last " .. interval .. " seconds]",
					"\n"
				)
			end
		end
	end

	local function on_trace_flush(self)
		if self._trace_count > 0 then
			local x, interval = self._should_warn_abort()

			if x and interval then
				io.write(
					"flushing ",
					tostring(self._trace_count),
					" traces, ",
					(x == 0 and "" or "[" .. x .. " times the last " .. interval .. " seconds]"),
					"\n"
				)
			end
		end

		self._traces = {}
		self._aborted = {}
		self._trace_count = 0
		self:EmitEvent({type = "trace_flush"})
		self._trace_generation = self._trace_generation + 1
	end

	-- --- Constructor ---
	function Profiler.New(
		config--[[#: {
			id = string | nil,
			path = string | nil,
			file_url = string | nil,
			mode = "line" | "function" | nil,
			depth = number | nil,
			sampling_rate = number | nil,
			flush_interval = number | nil,
			get_time = function=()>(number) | nil,
		} | nil]]
	)
		config = config or {}
		local self = setmetatable({}, Profiler)
		-- Config
		self._path = config.path or "./profiler_output.html"
		self._file_url = config.file_url or "vscode://file/${path}:${line}:1"
		self._mode = config.mode or "line"
		self._depth = config.depth or 999
		self._sampling_rate = config.sampling_rate or 1
		self._flush_interval = config.flush_interval or 3
		self._get_time = config.get_time

		if not self._get_time then
			time_function = time_function or get_time_function()
			self._get_time = time_function
		end

		-- Lifecycle
		self._time_start = self._get_time()
		self._running = true
		-- Event accumulation
		self._events = {}
		self._event_count = 0
		self._last_flush_time = 0
		-- String interning
		self._strings = {}
		self._string_lookup = {}
		self._string_count = 0
		self._strings_flushed = 0
		-- Section tracking
		self._section_stack = {}
		self._section_path = ""
		-- Trace tracking
		self._traces = {}
		self._trace_count = 0
		self._trace_generation = 0
		self._aborted = {}
		self._should_warn_mcode = create_warn_log(2)
		self._should_warn_abort = create_warn_log(8)
		-- HTML streaming
		self._last_flushed_idx = 0

		do
			local html = HTML_TEMPLATE
			html = html:gsub("%%FILE_URL_JSON%%", function()
				return json_string(self._file_url)
			end)
			local f = assert(io.open(self._path, "w"))
			f:write(html)
			f:flush()
			self._file = f
		end

		do
			self._trace_event_fn = function(what, tr, func, pc, otr, oex)
				if what == "start" then
					on_trace_start(self, tr, func, pc, otr, oex)
				elseif what == "stop" then
					on_trace_stop(self, tr, func)
				elseif what == "abort" then
					on_trace_abort(self, tr, func, pc, otr, oex)
				elseif what == "flush" then
					on_trace_flush(self)
				end
			end--[[# as jit_attach_trace]]
			self._trace_event_safe_fn = function(what, tr, func, pc, otr, oex)
				local ok, err = pcall(self._trace_event_fn--[[# as any]], what, tr, func, pc, otr, oex)

				if not ok then
					io.write("error in trace event (" .. tostring(what) .. "): " .. tostring(err) .. "\n")
				end
			end--[[# as jit_attach_trace]]
			jit.attach(self._trace_event_safe_fn, "trace")
		end

		do
			local dumpstack = jprofile.dumpstack
			local depth = self._depth

			jprofile.start((self._mode == "line" and "l" or "f") .. "i" .. self._sampling_rate, function(thread, sample_count, vmstate)
				self:EmitEvent(
					{
						type = "sample",
						stack = dumpstack(thread, "pl\n", depth),
						sample_count = sample_count,
						vm_state = vmstate,
						section_path = self._section_path,
					}
				)
				local now = self._get_time()

				if now - self._last_flush_time >= self._flush_interval then
					self._last_flush_time = now
					self:Save()
				end
			end)
		end

		return self
	end
end

do
	local function intern(self--[[#: TProfile]], s--[[#: string | nil]])
		if not s then return -1 end

		local idx = self._string_lookup[s]

		if idx then return idx end

		idx = self._string_count
		self._string_count = self._string_count + 1
		self._strings[idx] = s
		self._string_lookup[s] = idx
		return idx
	end

	local function get_new_strings(self--[[#: TProfile]])--[[#: List<|string|>]]
		local new = {}

		for i = self._strings_flushed, self._string_count - 1 do
			new[#new + 1] = self._strings[i]
		end

		self._strings_flushed = self._string_count
		return new
	end

	local function builtin_replace(n)
		local num = tonumber(n)
		return vmdef.ffnames[num] or ("[builtin#" .. n .. "]")
	end

	local function encode_event(self--[[#: TProfile]], ev--[[#: TEvent]])--[[#: string]]
		local ti = intern(self, ev.type)

		if ev.type == "sample" then
			local stack_str = ev.stack

			if stack_str and type(stack_str) == "string" then
				stack_str = stack_str:gsub("%[builtin#(%d+)%]", builtin_replace)
				stack_str = stack_str:gsub("@0x%x+\n?", "")
				stack_str = stack_str:gsub("%(command line%)[^\n]*\n?", "")
				stack_str = stack_str:gsub("%s+$", "")
			end

			local frames = {}

			if stack_str and stack_str ~= "" then
				for line in stack_str:gmatch("[^\n]+") do
					frames[#frames + 1] = intern(self, line)
				end
			end

			return string_format(
				"[%d,%.6f,[%s],%d,%d,%d]",
				ti,
				ev.time,
				table_concat(frames, ","),
				ev.sample_count or 0,
				intern(self, ev.vm_state),
				intern(self, ev.section_path)
			)
		elseif ev.type == "section_start" or ev.type == "section_end" then
			return string_format(
				"[%d,%.6f,%d,%d]",
				ti,
				ev.time,
				intern(self, ev.name),
				intern(self, ev.section_path)
			)
		elseif ev.type == "trace_start" then
			return string_format(
				"[%d,%.6f,%d,%d,%s,%s,%d,%d]",
				ti,
				ev.time,
				ev.id or 0,
				ev.generation or 0,
				ev.parent_id and tostring(ev.parent_id) or "null",
				ev.exit_id and tostring(ev.exit_id) or "null",
				ev.depth or 0,
				intern(self, ev.func_info)
			)
		elseif ev.type == "trace_stop" then
			return string_format(
				"[%d,%.6f,%d,%d,%d,%d,%s,%d,%d]",
				ti,
				ev.time,
				ev.id or 0,
				ev.generation or 0,
				intern(self, ev.func_info),
				intern(self, ev.linktype),
				ev.link_id and tostring(ev.link_id) or "null",
				ev.ir_count or 0,
				ev.exit_count or 0
			)
		elseif ev.type == "trace_abort" then
			return string_format(
				"[%d,%.6f,%d,%d,%s,%d,%d]",
				ti,
				ev.time,
				ev.id or 0,
				ev.generation or 0,
				ev.abort_code and tostring(ev.abort_code) or "null",
				intern(self, ev.abort_reason),
				intern(self, ev.func_info)
			)
		else
			return string_format("[%d,%.6f]", ti, ev.time)
		end
	end

	function Profiler:Save()
		if not self._file then return end

		local count = self._event_count

		if count > self._last_flushed_idx then
			local start_idx, end_idx = self._last_flushed_idx + 1, count

			if start_idx > end_idx then

			else
				local f = self._file

				if f then
					local event_parts = {}

					for i = start_idx, end_idx do
						event_parts[#event_parts + 1] = encode_event(self, assert(self._events[i], "nil event"))
					end

					local string_parts = {}

					for _, str in ipairs(get_new_strings(self)) do
						string_parts[#string_parts + 1] = json_string(str)
					end

					local strings_js, events_js = "[" .. table_concat(string_parts, ",") .. "]",
					"[" .. table_concat(event_parts, ",") .. "]"
					f:write("<script>_C(")
					f:write(strings_js)
					f:write(",")
					f:write(events_js)
					f:write(");</script>\n")
					f:flush()
					self._last_flushed_idx = count
				end
			end
		end
	end
end

function Profiler:Stop()
	if not self._running then return end

	self._running = false
	jprofile.stop()

	-- Detach trace events
	if self._trace_event_safe_fn then
		jit.attach(self._trace_event_safe_fn)
		self._trace_event_fn = nil
		self._trace_event_safe_fn = nil
	end

	-- Write remaining events and close file
	self:Save()
	local f = self._file

	if f then
		f:close()
		self._file = nil
	end
end

function Profiler:IsRunning()
	return self._running
end

function Profiler:GetElapsed()
	return self._get_time() - self._time_start
end

-- --- HTML Template ---
HTML_TEMPLATE = [==[
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Profiler</title>
<style>
:root {
  --accent:      #e0e0e0;
  --accent-dim:  rgba(224,224,224,0.15);
  --bg-base:     #1a1a1a;
  --bg-panel:    #222;
  --bg-elevated: #2a2a2a;
  --bg-hover:    #383838;
  --border:      #3030306c;
  --border-strong:#444;
  --text-muted:  #888;
  --text-dim:    #666;
  --color-ok:    #52b788;
  --color-abort: #ef6461;
  --color-stitch:#e9c46a;
  --color-linked:#ab47bc;
  --color-jit:   #ffd166;
  --color-select:#ffc832;
}
* { margin: 0; padding: 0; box-sizing: border-box; font-family: 'SF Mono', 'Consolas', 'Menlo', monospace; }
body { background: var(--bg-base); color: #e0e0e0; overflow-x: hidden; }

/* Custom Scrollbars */
::-webkit-scrollbar { width: 10px; height: 10px; }
::-webkit-scrollbar-track { background: var(--bg-base); }
::-webkit-scrollbar-thumb { background: var(--bg-elevated); border: 2px solid var(--bg-base); border-radius: 5px; }
::-webkit-scrollbar-thumb:hover { background: var(--bg-hover); }
::-webkit-scrollbar-corner { background: var(--bg-base); }

#header { padding: 8px 16px; background: var(--bg-panel); border-bottom: 1px solid var(--border); display: flex; align-items: center; gap: 16px; flex-wrap: wrap; position: relative; }
#header .stats { font-size: 13px; color: var(--text-muted); line-height: 1.4; }
#header .stats b { color: #fff; }
#header .header-controls { margin-left: auto; position: relative; display: flex; align-items: center; }
.options-gear { cursor: pointer; color: var(--text-dim); padding: 4px; border-radius: 4px; transition: color 0.2s, background 0.2s; user-select: none; font-size: 16px; }
.options-gear:hover { color: #fff; background: var(--bg-elevated); }
.options-dropdown { position: absolute; top: calc(100% + 8px); right: 0; background: var(--bg-panel); border: 1px solid var(--border-strong); border-radius: 6px; padding: 10px; min-width: 160px; z-index: 1000; box-shadow: 0 4px 12px rgba(0,0,0,0.5); display: none; flex-direction: column; gap: 8px; }
.options-dropdown.open { display: flex; }
.options-dropdown label { display: flex; align-items: center; gap: 8px; cursor: pointer; font-size: 11px; color: var(--text-muted); white-space: nowrap; user-select: none; }
.options-dropdown label:hover { color: #fff; }
#timeline-container { position: relative; background: #141414; border-bottom: none; cursor: crosshair; flex-shrink: 0; display: none; }
#timeline-container.open { display: block; }
#timeline-canvas { width: 100%; height: 100%; }
.tl-overlay-btn { position: absolute; font-size: 9px; font-weight: bold; color: var(--accent); white-space: nowrap; background: var(--bg-panel); border: 1px solid var(--accent-dim); padding: 0px 3px; border-radius: 3px; z-index: 110; cursor: pointer; user-select: none; opacity: 0.9; transition: opacity 0.2s, background 0.2s, color 0.2s, border-color 0.2s; box-shadow: 0 2px 4px rgba(0,0,0,0.3); }
.tl-overlay-btn:hover { background: var(--accent); color: var(--bg-elevated); opacity: 1; border-color: transparent; }
#btn-reset { bottom: -14px; left: 8px; display: none; }
#btn-zoom-sel { bottom: -14px; left: 0; display: none; }
.resize-handle { height: 16px; background: var(--bg-panel); border-bottom: 1px solid var(--border); cursor: ns-resize; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.resize-handle::after { content: ''; width: 40px; height: 2px; background: var(--border-strong); border-radius: 1px; }
.resize-handle:hover::after, .resize-handle.dragging::after { background: var(--accent); }
#selection-overlay { position: absolute; top: 0; bottom: 0; background: var(--accent-dim); border-left: 1px solid var(--accent); border-right: 1px solid var(--accent); pointer-events: none; display: none; overflow: visible; z-index: 10; }
#selection-overlay .tl-overlay-btn { pointer-events: auto; }
#selection-overlay::before, #selection-overlay::after { content: ''; position: absolute; top: 0; width: 1px; height: 100%; background: var(--accent); }
#selection-overlay::before { left: -1px; }
#selection-overlay::after { right: -1px; }
.sel-pin { position: absolute; top: -4px; width: 7px; height: 7px; background: var(--text-muted); transform: translateX(-50%) rotate(45deg); border: 1px solid var(--bg-base); }
.sel-pin.left { left: 0; }
.sel-pin.right { left: 100%; }

#timeline-controls { padding: 6px 16px; background: var(--bg-panel); border-bottom: 1px solid var(--border); display: flex; gap: 12px; align-items: center; font-size: 12px; flex-wrap: wrap; display: none; }
#timeline-controls.open { display: flex; }
.panel-btn { background: var(--bg-elevated); border: 1px solid var(--border-strong); color: #ccc; padding: 4px 12px; border-radius: 3px; cursor: pointer; font-size: 11px; }
.panel-btn:hover { background: var(--bg-hover); border-color: var(--accent); }
.sel-star { font-size: 10px; color: var(--color-select); margin-left: 8px; }
.btn-clear { margin-left: 6px; font-size: 10px; padding: 1px 7px; }
.sel-time-label { position: absolute; top: 0; font-size: 10px; font-weight: bold; color: var(--text-muted); white-space: nowrap; background: var(--bg-base); border: 1px solid var(--border-strong); padding: 1px 4px; border-radius: 3px; z-index: 100; box-shadow: 0 2px 4px rgba(0,0,0,0.5); pointer-events: none; }
.empty-msg { padding: 12px; color: var(--text-dim); }
#selection-info { color: var(--text-muted); }
#sample-filter-panel { background: var(--bg-panel); border-bottom: 1px solid var(--border); overflow: visible; display: none; }
#sample-filter-panel.open { display: block; }

#fg-section-filter { display: none; }
.section-header { padding: 0; background: var(--bg-panel); border-bottom: 1px solid var(--border); display: flex; align-items: stretch; flex-shrink: 0; cursor: pointer; }
.section-header button { background: transparent; border: none; color: var(--accent); padding: 6px 16px; cursor: pointer; font-size: 12px; font-weight: 600; width: 100%; text-align: left; display: flex; align-items: center; gap: 8px; line-height: 1.2; }
.section-header button::before { content: '▼'; display: inline-block; width: 1.2em; text-align: center; flex-shrink: 0; transition: transform 0.1s; font-size: 10px; }
.section-header button.collapsed::before { content: '▶'; }
.section-header:hover button { color: #fff; background: rgba(255,255,255,0.04); }
#trace-panel { background: var(--bg-panel); border-bottom: 1px solid var(--border); display: flex; flex-direction: column; overflow: hidden; height: 0; }
#trace-panel.open { overflow: hidden; }

#trace-sticky-top { position: sticky; top: 0; z-index: 2; background: var(--bg-panel); flex-shrink: 0; padding-right: 10px; /* Match standard scrollbar width */ }
#trace-filter-header { padding: 6px 16px; border-bottom: 1px solid var(--border); display: flex; align-items: center; gap: 8px; }
#trace-filter-header:empty { display: none; }
#trace-filter-header .panel-btn { padding: 2px 10px; }
#trace-panel-scroll { flex: 1; overflow: auto; position: relative; }
#trace-panel table { width: 100%; border-collapse: collapse; font-size: 11px; table-layout: fixed; margin: 0; padding: 0; border: none; }
#trace-panel .trace-header { background: var(--bg-elevated); table-layout: fixed; width: 100%; border: none; }
#trace-panel th, #trace-panel td { padding: 6px 10px; text-align: left; border-bottom: 1px solid var(--border-strong); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; box-sizing: border-box; }
#trace-panel th { color: var(--accent); font-weight: 600; cursor: pointer; user-select: none; position: relative; }
#trace-panel th:hover { color: #fff; }
#trace-panel th .th-resizer { position: absolute; top: 0; right: 0; bottom: 0; width: 5px; cursor: col-resize; user-select: none; z-index: 10; border-right: 1px solid var(--border-strong); }
#trace-panel th .th-resizer:hover { border-right-color: var(--accent); }
#trace-panel td { border-bottom: 1px solid var(--bg-panel); }
#trace-panel .col-id { width: 60px; }
#trace-panel .col-status { width: 140px; }
#trace-panel .col-depth { width: 45px; }
#trace-panel .col-location { width: auto; }
#trace-panel .col-parent { width: 120px; }
#trace-panel .col-time { width: 100px; }
#trace-panel .col-ir { width: 50px; }
#trace-panel .col-exits { width: 60px; }
#trace-panel thead tr th:last-child .th-resizer { display: none; }
#trace-panel tr.trace-row { cursor: pointer; }
#trace-panel tr.trace-row:hover td, #trace-panel tr.trace-row.hovered td { background: rgba(255,255,255,0.06); }
#trace-panel tr.trace-row.highlighted td { background: rgba(255,255,255,0.12); outline: 1px solid rgba(255,255,255,0.25); }
#trace-panel tr.trace-row.selected td { background: rgba(255,220,80,0.18); outline: 1px solid rgba(255,220,80,0.55); }
.trace-ok { color: var(--color-ok); }
.trace-linked { color: var(--color-linked); }
.trace-stitch { color: var(--color-stitch); }
.trace-abort { color: var(--color-abort); }
.trace-location { color: #aaa; }
.trace-id { color: #ccc; font-weight: 600; min-width: 40px; }
#filter-panel, #sample-filter-panel { background: var(--bg-panel); border-bottom: 1px solid var(--border); overflow: visible; }
#filter-panel .filter-grid, #sample-filter-panel .filter-grid { display: flex; flex-wrap: wrap; gap: 4px 16px; padding: 8px 16px; font-size: 11px; }
#filter-panel label, #sample-filter-panel label { display: flex; align-items: center; gap: 4px; cursor: pointer; padding: 2px 0; white-space: nowrap; }
#filter-panel label:hover, #sample-filter-panel label:hover { color: #fff; }
#filter-panel label.disabled, #sample-filter-panel label.disabled { color: #888; }
#filter-panel .filter-count, #sample-filter-panel .filter-count { color: var(--text-dim); font-size: 10px; }
.custom-cb { font-size: 13px; line-height: 1; font-family: monospace; display: inline-block; width: 1.1em; }
#filter-panel .filter-all-btn, #filter-panel .filter-none-btn, #sample-filter-panel .filter-all-btn, #sample-filter-panel .filter-none-btn { display: flex; align-items: center; gap: 4px; cursor: pointer; padding: 2px 0; white-space: nowrap; font-size: 11px; user-select: none; }
#filter-panel .filter-all-btn:hover, #filter-panel .filter-none-btn:hover, #sample-filter-panel .filter-all-btn:hover, #sample-filter-panel .filter-none-btn:hover { color: #fff; }
.filter-separator { width: 100%; height: 1px; background: var(--border); margin: 4px 0; }
#flamegraph-container { overflow: hidden; max-height: 0; flex-shrink: 0; }
#flamegraph-container.open { max-height: none; display: block; overflow-x: hidden; overflow-y: auto; flex: 1; }
#flamegraph-canvas { width: 100%; min-height: 400px; }
#tooltip { position: fixed; background: var(--bg-panel); border: 1px solid var(--border-strong); padding: 8px 12px; border-radius: 4px; font-size: 11px; pointer-events: none; display: none; z-index: 100; max-width: 500px; white-space: pre-wrap; line-height: 1.5; }
.loc-link { color: var(--accent); text-decoration: none; opacity: 0.8; }
.loc-link:hover { text-decoration: underline; opacity: 1; }
#main { display: flex; flex-direction: column; height: 100vh; }
#vm-pie-wrap { display: flex; align-items: center; flex-shrink: 0; }
#vm-pie-canvas { cursor: pointer; }
</style>
</head>
<body>
<div id="main">
<div id="header">
  <div id="vm-pie-wrap"><canvas id="vm-pie-canvas" width="72" height="72"></canvas></div>
  <span class="stats" id="stats"></span>
  <div class="header-controls">
    <div class="options-gear" id="btn-toggle-options" title="Settings">⚙</div>
    <div class="options-dropdown" id="options-dropdown">
      <label id="lbl-hover-preview">
        <span class="custom-cb" id="cb-hover-preview-indicator">☐</span>
        <input type="checkbox" id="cb-hover-preview" style="display:none"> hover preview
      </label>
    </div>
  </div>
</div>
<div class="section-header">
  <button id="btn-toggle-samples">samples</button>
</div>
<div id="sample-filter-panel" class="open"></div>
<div id="timeline-container" class="open">
  <canvas id="timeline-canvas"></canvas>
  <button id="btn-reset" class="tl-overlay-btn">reset zoom</button>
  <div id="selection-overlay">
    <div class="sel-pin left"></div>
    <div class="sel-pin right"></div>
    <span id="sel-t-start" class="sel-time-label" style="left:0;"></span>
    <span id="sel-t-end" class="sel-time-label" style="left:100%;"></span>
    <button id="btn-zoom-sel" class="tl-overlay-btn">zoom to selection</button>
  </div>
</div>
<div id="timeline-resize-handle" class="resize-handle"></div>
<div class="section-header">
  <button id="btn-toggle-aborts">traces</button>
</div>
<div id="trace-panel" class="open"></div>
<div id="trace-panel-resize-handle" class="resize-handle"></div>
<div class="section-header">
  <button id="btn-toggle-fg">flamegraph</button>
</div>
<div id="flamegraph-container" class="open">
  <div id="fg-section-filter"></div>
  <canvas id="flamegraph-canvas"></canvas>
</div>
</div>
<div id="tooltip"></div>

<script>
// --- Data accumulator & decoder ---
var _S=[],_E=[];
function _C(s,e){for(var i=0;i<s.length;i++)_S.push(s[i]);for(var i=0;i<e.length;i++)_E.push(e[i]);}
function _decode(S,E){
  var events=[];
  for(var i=0;i<E.length;i++){
    var d=E[i],type=S[d[0]],ev;
    if(type==='sample'){
      var frames=d[2],stack='';
      for(var j=0;j<frames.length;j++){if(j>0)stack+='\n';stack+=S[frames[j]];}
      ev={type:type,time:d[1],stack:stack,sample_count:d[3],vm_state:S[d[4]],section_path:S[d[5]]};
    }else if(type==='section_start'||type==='section_end'){
      ev={type:type,time:d[1],name:S[d[2]],section_path:S[d[3]]};
    }else if(type==='trace_start'){
      ev={type:type,time:d[1],id:d[2],generation:d[3],parent_id:d[4],exit_id:d[5],depth:d[6],func_info:S[d[7]]};
    }else if(type==='trace_stop'){
      ev={type:type,time:d[1],id:d[2],generation:d[3],func_info:S[d[4]],linktype:S[d[5]],link_id:d[6],ir_count:d[7],exit_count:d[8]};
    }else if(type==='trace_abort'){
      ev={type:type,time:d[1],id:d[2],generation:d[3],abort_code:d[4],abort_reason:S[d[5]],func_info:S[d[6]]};
    }else if(type==='trace_flush'){
      ev={type:type,time:d[1]};
    }else{
      ev={type:type,time:d[1]};
    }
    events.push(ev);
  }
  return events;
}
document.addEventListener('DOMContentLoaded', function() {
const EVENTS = _decode(_S, _E);
_S = null; _E = null;
const TOTAL_TIME = EVENTS.length > 1 ? EVENTS[EVENTS.length-1].time - EVENTS[0].time : 0;
const FILE_URL_TEMPLATE = %FILE_URL_JSON%;
// --- File link helper ---
function funcInfoLink(fi, label) {
  if (!fi) return label || '?';
  const display = label || fi;
  // Match "path/or/file.lua:line" — path may be absolute or relative
  const m = fi.match(/^(.+):([0-9]+)$/);
  if (!m) return display;
  const [, filePath, line] = m;
  const href = FILE_URL_TEMPLATE.replace(/\$\{path\}/g, filePath).replace(/\$\{line\}/g, line);
  return `<a class="loc-link" href="${href}">${display}</a>`;
}

// --- Colors ---
const COLORS = {
  // Accent / interaction
  accent:     '#e0e0e0',
  accentDim:  'rgba(224,224,224,0.15)',
  // Span / VM state
  ok:         '#52b788',
  abort:      '#ef6461',
  stitch:     '#e9c46a',
  linked:     '#ab47bc',
  jit:        '#ffd166',
  select:     '#ffc832',
  hover:      'rgba(255,255,255,0.06)',
  // Backgrounds / structure
  bgDeep:      '#141414',
  bgBase:      '#1a1a1a',
  bgPanel:     '#222',
  border:      '#333',
  borderStrong:'#444',
  bgSeparator: '#1e1e1e',
  // Text
  white:       '#fff',
  textBright:  '#ccc',
  textMid:     '#bbb',
  textMuted:   '#aaa',
  textDim:     '#888',
  textDimmer:  '#666',
  spanLabel:   '#111',
  // Canvas overlays / tooltips
  tooltipBg:    'rgba(15,15,35,0.75)',
  tooltipBgDim: 'rgba(15,15,35,0.72)',
  jitBand:      'rgba(255,241,118,0.07)',
  abortBand:    'rgba(239,100,97,0.15)',
  flushBand:    'rgba(255,107,107,0.08)',
  // Event / section colors
  okLight:      '#81c784',
  sectionStart: '#fff176',
  sectionEnd:   '#ffd54f',
  textFaint:    '#999',
  textVeryDim:  '#555',
  // Span tree connections
  selectTreeLine: 'rgba(255,200,50,0.85)',
  selectTreeFill: 'rgba(255,200,50,0.3)',
  hoverTreeLine:  'rgba(255,255,200,0.75)',
  hoverTreeFill:  'rgba(255,255,200,0.3)',
  selectGlow:     'rgba(255,200,50,0.9)',
};

// --- VM state helpers ---
const VM_STATE_COLORS = {
  'N': COLORS.ok,     // Native (JIT)
  'I': COLORS.stitch, // Interpreter
  'C': COLORS.linked, // C code
  'G': COLORS.abort,  // GC
  'J': COLORS.jit,    // JIT compile
};
const VM_STATE_LABELS = {
  'N': 'native',
  'I': 'interpreter',
  'C': 'c',
  'G': 'gc',
  'J': 'jit',
};

function sampleColor(e) {
  return VM_STATE_COLORS[e.vm_state] || COLORS.ok;
}

// --- Derived state ---
let timeOrigin = Infinity, timeEnd = -Infinity;
for (const e of EVENTS) {
  if (e.time < timeOrigin) timeOrigin = e.time;
  if (e.time > timeEnd) timeEnd = e.time;
}
const timeDuration = timeEnd - timeOrigin || 1;

let viewStart = 0, viewEnd = timeDuration;
let selStart = 0, selEnd = timeDuration;
let dragMode = null; // null | 'select' | 'pan'
let panStartX = 0, panViewStart0 = 0, panViewEnd0 = 0;
let autoScrollTimer = null;
let lastSelectX = 0;
let sampleH = 60; // updated each draw
let tlHovered = false;
let pieHoveredState = null; // vm_state key hovered on pie chart
let hoveredSection = null;  // section name being hovered in fg-section-filter
let pieSlices = [];  // [{state, a0, a1}] built by drawVmPie
let timelineContainerH = 0; // set after totalLanes is known

const ALL_SECTIONS = [];
const SECTION_OTHER = '__other__';
{
  const seen = new Set();
  let hasOther = false;
  for (const e of EVENTS) {
    if (e.type === 'section_start') {
      const name = e.name || '';
      if (name && !seen.has(name) && name !== SECTION_OTHER) { seen.add(name); ALL_SECTIONS.push(name); }
    }
    if (e.type === 'sample' && e.stack && !e.section_path) hasOther = true;
  }
  if (hasOther) ALL_SECTIONS.push(SECTION_OTHER);
}
const enabledSections = new Set(ALL_SECTIONS);
const enabledStates = new Set(['N', 'I', 'C', 'G', 'J']);

let hoverCategory = null;
let hoverAbortReason = null;
let hoverState = null;
let hoverSection = null;
const isHoverPreviewEnabled = () => document.getElementById('cb-hover-preview')?.checked;

function buildSampleFilterPanel(lo, hi) {
  const panel = document.getElementById('sample-filter-panel');
  if (!panel) return;

  const states = ['N', 'I', 'C', 'G', 'J'];
  const allStatesSelected = states.every(s => enabledStates.has(s));
  const allSectionsSelected = ALL_SECTIONS.every(s => enabledSections.has(s));
  const allSelected = allStatesSelected && allSectionsSelected;
  const noneSelected = enabledStates.size === 0 && enabledSections.size === 0;

  let html = '<div class="filter-grid">';

  // VM States
  states.forEach(state => {
    const isEnabled = enabledStates.has(state);
    const color = VM_STATE_COLORS[state] || COLORS.textDim;
    const label = VM_STATE_LABELS[state] || state;
    html += `<label class="${isEnabled ? '' : 'disabled'}" data-state="${state}"><span class="custom-cb">${isEnabled ? '☑' : '☐'}</span> <span style="color:${color}">■</span> ${label}</label>`;
  });

  if (ALL_SECTIONS.length > 0) {
    html += '<div class="filter-separator"></div>';
    ALL_SECTIONS.forEach(name => {
      const isEnabled = enabledSections.has(name);
      html += `<label class="${isEnabled ? '' : 'disabled'}" data-section="${name}"><span class="custom-cb">${isEnabled ? '☑' : '☐'}</span> ${name === SECTION_OTHER ? 'other' : name}</label>`;
    });
  }

  html += '</div>';
  panel.innerHTML = html;

  panel.addEventListener('mouseleave', () => {
    hoverState = null;
    hoverSection = null;
    hoveredSection = null;
    drawTimeline();
  });

  panel.querySelectorAll('label[data-state]').forEach(label => {
    label.addEventListener('click', () => {
      const state = label.dataset.state;
      if (enabledStates.has(state)) enabledStates.delete(state);
      else enabledStates.add(state);
      
      const isEnabled = enabledStates.has(state);
      label.querySelector('.custom-cb').textContent = isEnabled ? '☑' : '☐';
      label.classList.toggle('disabled', !isEnabled);
      
      hoverState = null;
      drawTimeline();
      scheduleFlamegraph(lo, hi);
      schedulePanelUpdate(lo, hi);
    });
    label.addEventListener('contextmenu', (e) => {
      e.preventDefault();
      const state = label.dataset.state;
      const isSolo = enabledStates.has(state) && enabledStates.size === 1 && enabledSections.size === ALL_SECTIONS.length;
      if (isSolo) {
        states.forEach(s => enabledStates.add(s));
      } else {
        enabledStates.clear();
        enabledStates.add(state);
      }
      hoverState = null;
      drawTimeline();
      buildSampleFilterPanel(lo, hi);
      scheduleFlamegraph(lo, hi);
      schedulePanelUpdate(lo, hi);
    });
    label.addEventListener('mouseenter', () => {
      if (!isHoverPreviewEnabled()) return;
      hoverState = label.dataset.state;
      drawTimeline();
    });
    label.addEventListener('mouseleave', () => {
      if (!isHoverPreviewEnabled()) return;
      hoverState = null;
      drawTimeline();
    });
  });
  panel.querySelectorAll('label[data-section]').forEach(label => {
    const name = label.dataset.section;
    label.addEventListener('click', () => {
      if (enabledSections.has(name)) enabledSections.delete(name);
      else enabledSections.add(name);
      
      const isEnabled = enabledSections.has(name);
      label.querySelector('.custom-cb').textContent = isEnabled ? '☑' : '☐';
      label.classList.toggle('disabled', !isEnabled);

      hoverSection = null;
      hoveredSection = null;
      drawTimeline();
      scheduleFlamegraph(lo, hi);
      schedulePanelUpdate(lo, hi);
    });
    label.addEventListener('contextmenu', (e) => {
      e.preventDefault();
      const isSolo = enabledSections.has(name) && enabledSections.size === 1 && enabledStates.size === states.length;
      if (isSolo) {
        ALL_SECTIONS.forEach(s => enabledSections.add(s));
      } else {
        enabledSections.clear();
        enabledSections.add(name);
      }
      hoverSection = null;
      hoveredSection = null;
      drawTimeline();
      buildSampleFilterPanel(lo, hi);
      scheduleFlamegraph(lo, hi);
      schedulePanelUpdate(lo, hi);
    });
    label.addEventListener('mouseenter', () => {
      hoverSection = name;
      if (name !== SECTION_OTHER) hoveredSection = name; 
      drawTimeline(); 
    });
    label.addEventListener('mouseleave', () => {
      hoverSection = null;
      hoveredSection = null;
      drawTimeline();
    });
  });
}

// Cached canvas rect — avoids forced layout reflow on every tick
let tlCanvasRectCache = null;
function getTlRect() {
  if (!tlCanvasRectCache) tlCanvasRectCache = tlCanvas.getBoundingClientRect();
  return tlCanvasRectCache;
}
function invalidateTlRect() { tlCanvasRectCache = null; }

// Debounced heavy updates (panels + flamegraph) so continuous wheel/drag only
// rebuilds DOM after the user pauses, keeping canvas draw synchronous.
let panelDebounceTimer = null;
let fgDebounceTimer = null;
let lastPanelRangeKey = "";
let lastFilterStateKey = "";

function schedulePanelUpdate(lo, hi) {
  if (panelDebounceTimer) clearTimeout(panelDebounceTimer);
  panelDebounceTimer = setTimeout(() => {
    buildTraceListPanel(lo, hi);
    buildFilterPanel(lo, hi);
    buildSampleFilterPanel(lo, hi);
    drawVmPie(lo, hi);
    panelDebounceTimer = null;
  }, 120);
}

function scheduleFlamegraph(lo, hi) {
  if (fgDebounceTimer) clearTimeout(fgDebounceTimer);
  fgDebounceTimer = setTimeout(() => {
    drawFlamegraph(lo, hi);
    fgDebounceTimer = null;
  }, 10); // Reduced delay for immediate feedback
}

function refreshView(lo, hi, immediate) {
  drawTimeline();
  updateSelOverlay();

  // If selection is exactly the current view (100% visible), 
  // then filtering (flamegraph/stats/panels) should follow the zoom.
  const isFullView = (selStart <= lo + 0.000001 && selEnd >= hi - 0.000001);
  const filterStart = isFullView ? lo : selStart;
  const filterEnd = isFullView ? hi : selEnd;

  updateStats(filterStart, filterEnd);
  if (immediate) {
    drawFlamegraph(filterStart, filterEnd);
    drawVmPie(filterStart, filterEnd);
    buildTraceListPanel(filterStart, filterEnd);
    buildFilterPanel(filterStart, filterEnd);
    buildSampleFilterPanel(filterStart, filterEnd);
  } else {
    scheduleFlamegraph(filterStart, filterEnd);
    schedulePanelUpdate(filterStart, filterEnd);
  }
}

// --- Stats ---
const statsEl = document.getElementById('stats');
function updateStats(lo, hi) {
  let count = 0;
  let totalSamples = 0;
  for (const e of EVENTS) {
    if (e.type === 'sample') {
      totalSamples++;
      const t = e.time - timeOrigin;
      if (t >= lo && t <= hi) count++;
    }
  }
  const dur = hi - lo;
  statsEl.innerHTML = `
    <b>${count}</b> / ${totalSamples} events<br>
    <b>${dur.toFixed(3)}</b> / ${TOTAL_TIME.toFixed(3)}s
  `;
}
updateStats(0, timeDuration);

// --- VM Pie Chart ---
const VM_STATE_ORDER = ['N','I','C','G','J'];
function drawVmPie(lo, hi) {
  const canvas = document.getElementById('vm-pie-canvas');
  if (!canvas) return;
  const size = 72;
  const ctx = setupCanvas(canvas, size, size);

  // Count samples in range
  const rangeCounts = {};
  let total = 0;
  for (const e of EVENTS) {
    if (e.type !== 'sample') continue;
    const t = e.time - timeOrigin;
    if (t < lo || t > hi) continue;
    const s = e.vm_state || '?';
    rangeCounts[s] = (rangeCounts[s] || 0) + 1;
    total++;
  }

  ctx.clearRect(0, 0, size, size);
  if (total === 0) {
    ctx.fillStyle = COLORS.border;
    ctx.fill();
    pieSlices = [];
    return;
  }

  const cx = size / 2, cy = size / 2;
  const outerR = size / 2 - 3;
  const innerR = outerR * 0.52;
  let angle = -Math.PI / 2;

  ctx.fillStyle = COLORS.bgBase;
  ctx.beginPath();
  ctx.arc(cx, cy, outerR, 0, Math.PI * 2);
  ctx.fill();

  pieSlices = [];
  const sliceData = [];
  for (const key of VM_STATE_ORDER) {
    const count = rangeCounts[key] || 0;
    if (!count) continue;
    const sweep = (count / total) * Math.PI * 2;
    sliceData.push({state: key, a0: angle, a1: angle + sweep, count});
    pieSlices.push({state: key, a0: angle, a1: angle + sweep});
    angle += sweep;
  }
  // Draw non-hovered slices first, then hovered on top
  for (const sl of sliceData) {
    const color = VM_STATE_COLORS[sl.state] || COLORS.textDim;
    const hov = sl.state === pieHoveredState;
    const r = hov ? outerR + 3 : outerR;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.arc(cx, cy, r, sl.a0, sl.a1);
    ctx.closePath();
    ctx.fillStyle = color;
    ctx.globalAlpha = hov ? 1 : (pieHoveredState ? 0.45 : 1);
    ctx.fill();
    ctx.globalAlpha = 1;
  }

  // Punch out the center for the donut hole
  ctx.fillStyle = COLORS.bgPanel;
  ctx.beginPath();
  ctx.arc(cx, cy, innerR, 0, Math.PI * 2);
  ctx.fill();

  // Center label: hovered state key or total count
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  if (pieHoveredState) {
    const cnt = rangeCounts[pieHoveredState] || 0;
    const pct = (cnt / total * 100).toFixed(0) + '%';
    const stateColor = VM_STATE_COLORS[pieHoveredState] || COLORS.textMuted;
    // Background pill behind labels
    const bgW = innerR * 1.7, bgH = innerR * 1.25;
    ctx.fillStyle = COLORS.bgDeep;
    ctx.beginPath();
    ctx.roundRect(cx - bgW / 2, cy - bgH / 2, bgW, bgH, 5);
    ctx.fill();
    ctx.fillStyle = stateColor;
    ctx.font = 'bold 9px monospace';
    ctx.fillText(pieHoveredState, cx, cy - 5);
    ctx.fillStyle = COLORS.textBright;
    ctx.font = 'bold 10px monospace';
    ctx.fillText(pct, cx, cy + 6);
  }
}

// --- Trace List ---
function traceStatusClass(span) {
  if (span.outcome === 'abort') return 'trace-abort';
  const lt = span.end.linktype;
  if (lt === 'stitch') return 'trace-stitch';
  if (lt === 'root') return 'trace-linked';
  return 'trace-ok';
}
function traceStatusLabel(span) {
  if (span.outcome === 'abort') return span.end.abort_reason || 'aborted';
  const lt = span.end.linktype || '?';
  const lk = span.end.link_id ? ' → #' + span.end.link_id : '';
  return lt + lk;
}
let traceListSortKey = 'id';
let traceListSortAsc = true;

function clearSelectionHtml(spanId, label) {
  return ' <span class="sel-star">&#9733; ' + label + '</span><button id="btn-clear-selection" class="panel-btn btn-clear">Clear</button>';
}
function wireClearBtn(lo, hi) {
  const btn = document.getElementById('btn-clear-selection');
  if (btn) btn.addEventListener('click', () => { selectedSpan = null; drawTimeline(); buildTraceListPanel(lo, hi); });
}

function buildTraceListPanel(tStart, tEnd) {
  const lo = tStart !== undefined ? tStart : viewStart;
  const hi = tEnd !== undefined ? tEnd : viewEnd;

  // When a span is selected, collect its entire ancestor+descendant tree
  let selectedTree = null;
  if (selectedSpan) {
    selectedTree = new Set();
    // Walk up to root
    let anc = selectedSpan;
    while (anc) {
      selectedTree.add(anc.uid);
      anc = anc.start.parent_id ? spanByUid[traceUid(anc.start.generation, anc.start.parent_id)] : null;
    }
    // BFS down descendants
    const q = [selectedSpan];
    while (q.length) {
      const n = q.shift();
      selectedTree.add(n.uid);
      const kids = childrenOfUid[n.uid];
      if (kids) for (const k of kids) q.push(k);
    }
  }

  const visible = [];
  for (const span of traceSpans) {
    if (hoverCategory) {
      if (span.category !== hoverCategory) continue;
      if (hoverCategory === 'aborted' && hoverAbortReason && span.abort_reason !== hoverAbortReason) continue;
    } else {
      if (!enabledCategories.has(span.category)) continue;
      if (span.abort_reason && !enabledAbortReasons.has(span.abort_reason)) continue;
    }
    // If a span is selected, only show its tree; otherwise filter by time range
    if (selectedTree) {
      if (!selectedTree.has(span.uid)) continue;
    } else {
      const t = span.t0 - timeOrigin;
      if (t < lo || t > hi) continue;
    }
    visible.push(span);
  }
  const container = document.getElementById('trace-panel');
  if (visible.length === 0) {
    let emptyHdr = '<div id="trace-sticky-top"><div id="trace-filter-header">';
    if (selectedSpan) emptyHdr += clearSelectionHtml(selectedSpan.id, '#' + selectedSpan.id);
    emptyHdr += '</div><div id="filter-panel"></div></div><div class="empty-msg">No traces in range.</div>';
    container.innerHTML = emptyHdr;
    buildFilterPanel(lo, hi);
    wireClearBtn(lo, hi);
    return;
  }

  // Sort
  const cmp = (a, b) => {
    let va, vb;
    switch (traceListSortKey) {
      case 'id': va = a.id; vb = b.id; break;
      case 'status': va = a.outcome + (a.end.linktype||''); vb = b.outcome + (b.end.linktype||''); break;
      case 'depth': va = a.depth; vb = b.depth; break;
      case 'location': va = a.start.func_info||''; vb = b.start.func_info||''; break;
      case 'time': va = a.t0; vb = b.t0; break;
      default: va = a.id; vb = b.id;
    }
    if (va < vb) return traceListSortAsc ? -1 : 1;
    if (va > vb) return traceListSortAsc ? 1 : -1;
    return 0;
  };
  visible.sort(cmp);

  const arrow = traceListSortAsc ? ' ▲' : ' ▼';
  const hdr = (key, label, cls) => {
    const active = traceListSortKey === key;
    return '<th data-sort="' + key + '" class="' + (cls || '') + '">' + label + (active ? arrow : '') + '<div class="th-resizer"></div></th>';
  };
  let html = '<div id="trace-sticky-top"><div id="trace-filter-header">';
  if (selectedSpan) {
    html += clearSelectionHtml(selectedSpan.id, 'Showing tree for #' + selectedSpan.id);
  }
  html += '</div><div id="filter-panel"></div>';
  html += '<table class="trace-header"><thead><tr>' +
    hdr('id','id','col-id') +
    hdr('status','status','col-status') +
    hdr('depth','depth','col-depth') +
    hdr('location','location','col-location') +
    hdr('parent', 'parent', 'col-parent') +
    hdr('time','time','col-time') +
    hdr('ir','ir','col-ir') +
    hdr('exits','exits','col-exits') +
    '</tr></thead></table></div>';
  html += '<div id="trace-panel-scroll"><table><thead><tr style="height:0; visibility:collapse;">' +
    '<th class="col-id"></th><th class="col-status"></th><th class="col-depth"></th><th class="col-location"></th>' +
    '<th class="col-parent"></th><th class="col-time"></th><th class="col-ir"></th><th class="col-exits"></th>' +
    '</tr></thead><tbody>';
  for (const s of visible) {
    const cls = traceStatusClass(s);
    const irCount = s.end.ir_count || '';
    const exitCount = s.end.exit_count || '';
    const parentInfo = s.start.parent_id ? '#' + s.start.parent_id + ' exit ' + s.start.exit_id : '';
    const t = (s.t0 - timeOrigin).toFixed(4) + 's';
    const selCls = (selectedSpan && s.uid === selectedSpan.uid) ? ' selected' : '';
    html += '<tr class="trace-row' + selCls + '" data-span-uid="' + s.uid + '">' +
      '<td class="col-id">#' + s.id + '</td>' +
      '<td class="' + cls + ' col-status">' + traceStatusLabel(s) + '</td>' +
      '<td class="col-depth">' + s.depth + '</td>' +
      '<td class="trace-location col-location">' + funcInfoLink(s.start.func_info) + '</td>' +
      '<td class="col-parent">' + parentInfo + '</td>' +
      '<td class="col-time">' + t + '</td>' +
      '<td class="col-ir">' + irCount + '</td>' +
      '<td class="col-exits">' + exitCount + '</td></tr>';
  }
  html += '</tbody></table></div>';
  container.innerHTML = html;

  buildFilterPanel(lo, hi);
  wireClearBtn(lo, hi);

  // Sort header click handlers
  container.querySelectorAll('th[data-sort]').forEach(th => {
    th.addEventListener('click', (ev) => {
      if (ev.target.classList.contains('th-resizer')) return;
      const key = th.dataset.sort;
      if (traceListSortKey === key) traceListSortAsc = !traceListSortAsc;
      else { traceListSortKey = key; traceListSortAsc = true; }
      buildTraceListPanel(lo, hi);
    });

    const resizer = th.querySelector('.th-resizer');
    if (resizer) {
      resizer.addEventListener('mousedown', (ev) => {
        ev.stopPropagation();
        const startX = ev.clientX;
        const startW = th.getBoundingClientRect().width;
        
        const onMouseMove = (moveEv) => {
          const newW = Math.max(30, startW + (moveEv.clientX - startX));
          const cls = th.className.split(' ').find(c => c.startsWith('col-'));
          if (cls) {
            // Find or create style tag for dynamic resizing
            let styleTag = document.getElementById('dynamic-column-styles');
            if (!styleTag) {
              styleTag = document.createElement('style');
              styleTag.id = 'dynamic-column-styles';
              document.head.appendChild(styleTag);
            }
            const selector = '#trace-panel .' + cls;
            const newRule = selector + ' { width: ' + newW + 'px !important; }';
            
            // Efficiently update the rule
            const sheet = styleTag.sheet;
            let ruleIdx = -1;
            for (let i = 0; i < sheet.cssRules.length; i++) {
              if (sheet.cssRules[i].selectorText === selector) { ruleIdx = i; break; }
            }
            if (ruleIdx !== -1) sheet.deleteRule(ruleIdx);
            sheet.insertRule(newRule, 0);
          }
        };
        const onMouseUp = () => {
          window.removeEventListener('mousemove', onMouseMove);
          window.removeEventListener('mouseup', onMouseUp);
          document.body.style.cursor = '';
        };
        window.addEventListener('mousemove', onMouseMove);
        window.addEventListener('mouseup', onMouseUp);
        document.body.style.cursor = 'col-resize';
      });
    }
  });

  // Row hover + click handlers
  container.querySelectorAll('tr.trace-row').forEach(row => {
    row.addEventListener('click', (ev) => {
      if (ev.target.closest('a')) return; // let link navigate, don't select row
      const uid = row.dataset.spanUid;
      const span = spanByUid[uid];
      if (!span) return;
      selectedSpan = (selectedSpan === span) ? null : span;
      drawTimeline();
      buildTraceListPanel(lo, hi);
    });
    row.addEventListener('mouseenter', () => {
      const uid = row.dataset.spanUid;
      const span = spanByUid[uid];
      if (span && lastHoveredSpan !== span) {
        lastHoveredSpan = span;
        drawTimeline();
      }
      row.classList.add('hovered');
    });
    row.addEventListener('mouseleave', () => {
      row.classList.remove('hovered');
      if (lastHoveredSpan) {
        lastHoveredSpan = null;
        drawTimeline();
      }
    });
  });
}


document.getElementById('btn-toggle-samples').addEventListener('click', () => {
  const panel = document.getElementById('sample-filter-panel');
  const ctrl = document.getElementById('timeline-controls');
  const container = document.getElementById('timeline-container');
  const rh = document.getElementById('timeline-resize-handle');
  const btn = document.getElementById('btn-toggle-samples');
  const isOpen = container.classList.toggle('open');
  panel.classList.toggle('open', isOpen);
  btn.classList.toggle('collapsed', !isOpen);
  rh.style.display = isOpen ? '' : 'none';
  if (isOpen) {
    drawTimeline();
    buildSampleFilterPanel(viewStart, viewEnd);
  }
});

document.getElementById('btn-toggle-aborts').addEventListener('click', () => {
  const panel = document.getElementById('trace-panel');
  const btn = document.getElementById('btn-toggle-aborts');
  const rh = document.getElementById('trace-panel-resize-handle');
  const isOpen = panel.classList.toggle('open');
  btn.classList.toggle('collapsed', !isOpen);
  panel.style.height = isOpen ? tracePanelH + 'px' : '0px';
  rh.style.display = isOpen ? '' : 'none';
});
document.getElementById('btn-toggle-fg').addEventListener('click', () => {
  const container = document.getElementById('flamegraph-container');
  const btn = document.getElementById('btn-toggle-fg');
  const isOpen = container.classList.toggle('open');
  btn.classList.toggle('collapsed', !isOpen);
  if (isOpen) drawFlamegraph(viewStart, viewEnd);
});

// Sync: highlight traces row when timeline hover changes
function syncTraceListHighlight(span) {
  const panel = document.getElementById('trace-panel');
  if (!panel) return;
  // Remove previous transient highlight (not the selected one)
  const prev = panel.querySelector('tr.trace-row.highlighted');
  if (prev) prev.classList.remove('highlighted');
  if (!span) return;
  const row = panel.querySelector('tr.trace-row[data-span-id="' + span.id + '"]');
  if (row) {
    if (!row.classList.contains('selected')) row.classList.add('highlighted');
    if (panel.classList.contains('open')) {
      row.scrollIntoView({block: 'nearest', behavior: 'instant'});
    }
  }
}

// --- Build trace spans (connect start → stop/abort) with depth-based nesting ---
// Use generation:id as unique key (uid) so trace ID reuse across flushes is safe
function traceUid(gen, id) { return gen + ':' + id; }
const traceSpans = [];
const spanByUid = {};
const childrenOfUid = {};
const flushTimes = [];
{
  const pending = {};
  for (const e of EVENTS) {
    if (e.type === 'trace_start') {
      pending[traceUid(e.generation, e.id)] = e;
    } else if (e.type === 'trace_stop' || e.type === 'trace_abort') {
      const uid = traceUid(e.generation, e.id);
      const start = pending[uid];
      if (start) {
        const parentUid = start.parent_id != null ? traceUid(start.generation, start.parent_id) : null;
        const span = {
          id: e.id,
          uid: uid,
          generation: e.generation,
          t0: start.time,
          t1: e.time,
          start: start,
          end: e,
          depth: start.depth || 0,
          outcome: e.type === 'trace_stop' ? 'stop' : 'abort',
          category: (function() {
            if (e.type === 'trace_stop') {
              const lt = e.linktype || '?';
              if (lt === 'root') return 'linked';
              if (lt === 'stitch') return 'stitch';
              return 'OK';
            }
            return 'aborted';
          })(),
          abort_reason: e.type === 'trace_abort' ? (e.abort_reason || '?') : null,
        };
        traceSpans.push(span);
        spanByUid[uid] = span;
        if (parentUid) {
          if (!childrenOfUid[parentUid]) childrenOfUid[parentUid] = [];
          childrenOfUid[parentUid].push(span);
        }
        delete pending[uid];
      }
    } else if (e.type === 'trace_flush') {
      flushTimes.push(e.time);
      for (const uid in pending) delete pending[uid];
    }
  }
}
traceSpans.sort((a, b) => a.t0 - b.t0);

// Compute max depth for layout
let maxTraceDepth = 0;
for (const span of traceSpans) {
  if (span.depth > maxTraceDepth) maxTraceDepth = span.depth;
}
const totalLanes = Math.max(5, maxTraceDepth);

let visibleSpanRects = [];
let lastHoveredSpan = null;
let selectedSpan = null;
let panClickSpanCandidate = null; // span under cursor at mousedown in trace area

// --- Trace filter ---
const allTraceCategories = {};
const allAbortReasons = {};
for (const span of traceSpans) {
  allTraceCategories[span.category] = (allTraceCategories[span.category] || 0) + 1;
  if (span.abort_reason) {
    allAbortReasons[span.abort_reason] = (allAbortReasons[span.abort_reason] || 0) + 1;
  }
}
{
  let fc = 0;
  for (const e of EVENTS) if (e.type === 'trace_flush') fc++;
  if (fc > 0) allTraceCategories['flush'] = fc;
}
const enabledCategories = new Set(Object.keys(allTraceCategories));
const enabledAbortReasons = new Set(Object.keys(allAbortReasons));

const mainCategoryOrder = ['OK', 'linked', 'stitch', 'aborted', 'flush'];
const categoryList = mainCategoryOrder.map(cat => [cat, allTraceCategories[cat] || 0]);

const abortReasonList = Object.entries(allAbortReasons).sort((a, b) => b[1] - a[1]);

function buildFilterPanel(tStart, tEnd) {
  const lo = (tStart !== undefined) ? tStart : viewStart;
  const hi = (tEnd !== undefined) ? tEnd : viewEnd;
  const panel = document.getElementById('filter-panel');

  // Recalculate what categories are actually visible in current range
  const zoomCategories = {};
  const zoomAbortReasons = {};
  for (const span of traceSpans) {
    const t = span.t0 - timeOrigin;
    if (span.t1 - timeOrigin < lo || t > hi) continue;
    zoomCategories[span.category] = (zoomCategories[span.category] || 0) + 1;
    if (span.abort_reason) {
      zoomAbortReasons[span.abort_reason] = (zoomAbortReasons[span.abort_reason] || 0) + 1;
    }
  }
  {
    for (const e of EVENTS) {
      if (e.type !== 'trace_flush') continue;
      const t = e.time - timeOrigin;
      if (t < lo || t > hi) continue;
      zoomCategories['flush'] = (zoomCategories['flush'] || 0) + 1;
    }
  }

  const allSelected = categoryList.every(([cat]) => enabledCategories.has(cat)) && abortReasonList.every(([r]) => enabledAbortReasons.has(r));
  const noneSelected = enabledCategories.size === 0 && enabledAbortReasons.size === 0;

  const totalZoom = Object.values(zoomCategories).reduce((a,b)=>a+b,0) + Object.values(zoomAbortReasons).reduce((a,b)=>a+b,0);

  let html = '<div class="filter-grid">';
  
  // Main categories
  categoryList.forEach(([cat, count], idx) => {
    let color = COLORS.ok;
    if (cat === 'aborted') color = COLORS.abort;
    if (cat === 'stitch') color = COLORS.stitch;
    if (cat === 'linked') color = COLORS.linked;
    if (cat === 'flush') color = COLORS.abort;

    const isEnabled = enabledCategories.has(cat);
    const checkedChar = isEnabled ? '☑' : '☐';
    const escaped = cat.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;');
    const zoomCount = zoomCategories[cat] || 0;
    const countStyle = zoomCount === 0 ? `color:${COLORS.borderStrong}` : `color:${COLORS.textFaint}`;
    let icon = `<span style="color:${color}">■</span>`;
    if (cat === 'flush') {
      icon = `<span style="color:${color}; border: 1px dashed ${color}; width: 10px; height: 10px; display: inline-block; vertical-align: middle; margin-right: 2px;"></span>`;
    }
    html += `<label class="${isEnabled ? '' : 'disabled'}" style="${zoomCount === 0 ? 'opacity:0.5' : ''}" data-cat-idx="${idx}"><span class="custom-cb">${checkedChar}</span> ${icon} ${escaped} <span class="filter-count" style="${countStyle}">(${zoomCount})</span></label>`;
  });

  const abortedChecked = enabledCategories.has('aborted');
  if (abortedChecked && abortReasonList.length > 0) {
    html += '<div class="filter-separator"></div>';
    // Abort reasons
    abortReasonList.forEach(([reason, count], idx) => {
      const isEnabled = enabledAbortReasons.has(reason);
      const checkedChar = isEnabled ? '☑' : '☐';
      const escaped = reason.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;');
      const zoomCount = zoomAbortReasons[reason] || 0;
      const countStyle = zoomCount === 0 ? `color:${COLORS.borderStrong}` : `color:${COLORS.textFaint}`;
      html += `<label class="${isEnabled ? '' : 'disabled'}" style="${zoomCount === 0 ? 'opacity:0.5' : ''}" data-reason-idx="${idx}"><span class="custom-cb">${checkedChar}</span> ${escaped} <span class="filter-count" style="${countStyle}">(${zoomCount})</span></label>`;
    });
  }

  html += '</div>';
  panel.innerHTML = html;

  panel.addEventListener('mouseleave', () => {
    hoverCategory = null;
    hoverAbortReason = null;
    drawTimeline();
  });

  panel.querySelectorAll('label[data-cat-idx]').forEach(label => {
    label.addEventListener('click', () => {
      const idx = parseInt(label.dataset.catIdx);
      const cat = categoryList[idx][0];
      if (enabledCategories.has(cat)) {
        enabledCategories.delete(cat);
      } else {
        enabledCategories.add(cat);
        // Reset all abort reasons to checked when "aborted" is re-enabled
        if (cat === 'aborted') {
          abortReasonList.forEach(([reason]) => enabledAbortReasons.add(reason));
        }
      }
      
      const isEnabled = enabledCategories.has(cat);
      label.querySelector('.custom-cb').textContent = isEnabled ? '☑' : '☐';
      label.classList.toggle('disabled', !isEnabled);

      hoverCategory = null;
      hoverAbortReason = null;
      drawTimeline();
      // Use buildFilterPanel directly since we need to toggle the visibility of the reasons section immediately
      buildFilterPanel(lo, hi);
      schedulePanelUpdate(lo, hi);
      scheduleFlamegraph(lo, hi);
    });
    label.addEventListener('contextmenu', (e) => {
      e.preventDefault();
      const idx = parseInt(label.dataset.catIdx);
      const cat = categoryList[idx][0];
      
      const isSolo = enabledCategories.has(cat) && enabledCategories.size === 1;
      if (isSolo) {
        // Inverse: check everything except aborted reasons (just the main categories)
        categoryList.forEach(([c]) => enabledCategories.add(c));
        abortReasonList.forEach(([r]) => enabledAbortReasons.add(r));
      } else {
        enabledCategories.clear();
        enabledCategories.add(cat);
        if (cat === 'aborted') {
          abortReasonList.forEach(([reason]) => enabledAbortReasons.add(reason));
        } else {
          enabledAbortReasons.clear();
        }
      }
      hoverCategory = null;
      hoverAbortReason = null;
      drawTimeline();
      buildFilterPanel(lo, hi);
      schedulePanelUpdate(lo, hi);
      scheduleFlamegraph(lo, hi);
    });
    label.addEventListener('mouseenter', () => {
      if (!isHoverPreviewEnabled()) return;
      const idx = parseInt(label.dataset.catIdx);
      hoverCategory = categoryList[idx][0];
      drawTimeline();
    });
    label.addEventListener('mouseleave', () => {
      if (!isHoverPreviewEnabled()) return;
      hoverCategory = null;
      drawTimeline();
    });
  });
  panel.querySelectorAll('label[data-reason-idx]').forEach(label => {
    label.addEventListener('click', () => {
      const idx = parseInt(label.dataset.reasonIdx);
      const reason = abortReasonList[idx][0];
      if (enabledAbortReasons.has(reason)) enabledAbortReasons.delete(reason);
      else enabledAbortReasons.add(reason);
      
      const isEnabled = enabledAbortReasons.has(reason);
      label.querySelector('.custom-cb').textContent = isEnabled ? '☑' : '☐';
      label.classList.toggle('disabled', !isEnabled);

      hoverCategory = null;
      hoverAbortReason = null;
      drawTimeline();
      schedulePanelUpdate(lo, hi);
      scheduleFlamegraph(lo, hi);
    });
    label.addEventListener('contextmenu', (e) => {
      e.preventDefault();
      const idx = parseInt(label.dataset.reasonIdx);
      const reason = abortReasonList[idx][0];

      const isSolo = enabledCategories.size === 1 && enabledCategories.has('aborted') && 
                     enabledAbortReasons.size === 1 && enabledAbortReasons.has(reason);
      
      if (isSolo) {
        categoryList.forEach(([c]) => enabledCategories.add(c));
        abortReasonList.forEach(([r]) => enabledAbortReasons.add(r));
      } else {
        enabledCategories.clear();
        enabledCategories.add('aborted');
        enabledAbortReasons.clear();
        enabledAbortReasons.add(reason);
      }
      hoverCategory = null;
      hoverAbortReason = null;
      drawTimeline();
      buildFilterPanel(lo, hi);
      schedulePanelUpdate(lo, hi);
      scheduleFlamegraph(lo, hi);
    });
    label.addEventListener('mouseenter', () => {
      if (!isHoverPreviewEnabled()) return;
      const idx = parseInt(label.dataset.reasonIdx);
      hoverAbortReason = abortReasonList[idx][0];
      hoverCategory = 'aborted';
      drawTimeline();
    });
    label.addEventListener('mouseleave', () => {
      if (!isHoverPreviewEnabled()) return;
      hoverAbortReason = null;
      hoverCategory = null;
      drawTimeline();
    });
  });

  document.getElementById('filter-all')?.addEventListener('click', () => {
    categoryList.forEach(([cat]) => enabledCategories.add(cat));
    abortReasonList.forEach(([reason]) => enabledAbortReasons.add(reason));
    drawTimeline();
    buildFilterPanel(lo, hi);
    schedulePanelUpdate(lo, hi);
  });
  document.getElementById('filter-none')?.addEventListener('click', () => {
    enabledCategories.clear();
    enabledAbortReasons.clear();
    drawTimeline();
    buildFilterPanel(lo, hi);
    schedulePanelUpdate(lo, hi);
  });
}
buildTraceListPanel();

// --- Timeline ---
const tlCanvas = document.getElementById('timeline-canvas');
const tlCtx = tlCanvas.getContext('2d');
const selOverlay = document.getElementById('selection-overlay');
const tooltip = document.getElementById('tooltip');

function showTooltip(html, x, y) {
  tooltip.innerHTML = html;
  tooltip.style.pointerEvents = 'none';
  tooltip.style.display = 'block';
  tooltip.style.left = x + 'px';
  tooltip.style.top = y + 'px';
}
function hideTooltip() { tooltip.style.display = 'none'; }

function formatSelInfo(lo, hi) {
  return 'selected: ' + (hi - lo).toFixed(4) + 's (' + lo.toFixed(4) + 's \u2014 ' + hi.toFixed(4) + 's)';
}

function setupCanvas(canvas, w, h) {
  const dpr = window.devicePixelRatio || 1;
  canvas.width = w * dpr;
  canvas.height = h * dpr;
  canvas.style.width = w + 'px';
  canvas.style.height = h + 'px';
  const ctx = canvas.getContext('2d');
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  return ctx;
}

function eventColor(e) {
  switch(e.type) {
    case 'sample': return sampleColor(e);
    case 'trace_start': return COLORS.okLight;
    case 'trace_stop': return COLORS.ok;
    case 'trace_abort': return COLORS.abort;
    case 'trace_flush': return COLORS.abort;
    case 'section_start': return COLORS.sectionStart;
    case 'section_end': return COLORS.sectionEnd;
    default: return COLORS.textFaint;
  }
}

function resizeCanvas(canvas) {
  const rect = canvas.parentElement.getBoundingClientRect();
  setupCanvas(canvas, rect.width, rect.height);
  return rect;
}

function drawTimeline() {
  const rect = resizeCanvas(tlCanvas);
  const w = rect.width, h = rect.height;

  const currentRange = (selStart !== null && selEnd !== null) 
    ? [Math.min(selStart, selEnd), Math.max(selStart, selEnd)] 
    : [viewStart, viewEnd];

  tlCtx.fillStyle = COLORS.bgDeep;

  const vDur = viewEnd - viewStart || 1;

  // Layout: vm state (top, smaller) + traces (bottom, larger)
  sampleH = Math.min(30, Math.max(20, Math.round(h * 0.14)));
  const traceY = sampleH + 4; // 4px gap for divider
  const traceH = h - traceY;

  // Draw section bands first (background)
  const sectionStarts = {};
  for (const e of EVENTS) {
    const t = e.time - timeOrigin;
    if (t < viewStart || t > viewEnd) continue;
    const x = ((t - viewStart) / vDur) * w;
    if (e.type === 'section_start') {
      const secName = e.name || '';
      if (hoveredSection !== secName) continue;
      sectionStarts[e.section_path || e.name] = x;
    } else if (e.type === 'section_end') {
      const secName = e.name || '';
      if (hoveredSection !== secName) continue;
      const key = (e.section_path ? e.section_path + (e.name ? ' > ' + e.name : '') : e.name) || '';
      for (const k of Object.keys(sectionStarts)) {
        if (key.startsWith(k) || k.startsWith(key) || k === e.name) {
          const sx = sectionStarts[k];
          tlCtx.fillStyle = COLORS.jitBand;
          tlCtx.fillRect(sx, 0, x - sx, h);
          delete sectionStarts[k];
          break;
        }
      }
    }
  }

  // Draw trace_flush as subtle bands in sample area (prominent rendering is in trace area below)
  if (enabledCategories.has('flush')) {
    for (const ft of flushTimes) {
      const t = ft - timeOrigin;
      if (t < viewStart || t > viewEnd) continue;
      const x = ((t - viewStart) / vDur) * w;
      tlCtx.fillStyle = COLORS.abortBand;
      tlCtx.fillRect(x - 2, 0, 4, sampleH);
      tlCtx.fillStyle = COLORS.abort;
      tlCtx.fillRect(x, 0, 1, sampleH);
    }
  }

  // Draw samples and section boundaries
  for (const e of EVENTS) {
    if (e.type.startsWith('trace_')) continue;
    const t = e.time - timeOrigin;
    if (t < viewStart || t > viewEnd) continue;
    const x = ((t - viewStart) / vDur) * w;

    if (e.type === 'sample') {
      let isVisible;
      if (hoverState || hoverSection) {
        isVisible = (!hoverState || e.vm_state === hoverState) && (!hoverSection || e.section_path === hoverSection);
      } else {
        const isVisibleState = enabledStates.has(e.vm_state);
        const isVisibleSection = !e.section_path || enabledSections.has(e.section_path);
        isVisible = isVisibleState && isVisibleSection;
      }
      if (!isVisible) continue;
      const matchesPie = !pieHoveredState || e.vm_state === pieHoveredState;
      if (!matchesPie) continue;
      tlCtx.fillStyle = sampleColor(e);
      tlCtx.globalAlpha = 0.8;
      tlCtx.fillRect(x, 2, 1.5, sampleH - 4);
      tlCtx.globalAlpha = 1;
    } else if (e.type === 'section_start' || e.type === 'section_end') {
      if (hoveredSection !== (e.name || '')) continue;
      tlCtx.fillStyle = eventColor(e);
      tlCtx.globalAlpha = 0.4;
      tlCtx.fillRect(x, 0, 1, h);
      tlCtx.globalAlpha = 1;
    }
  }

  tlCtx.strokeStyle = COLORS.borderStrong;
  tlCtx.lineWidth = 1;
  tlCtx.beginPath();
  tlCtx.moveTo(0, sampleH + 2);
  tlCtx.lineTo(w, sampleH + 2);
  tlCtx.stroke();

  tlCtx.strokeStyle = COLORS.bgSeparator;
  tlCtx.lineWidth = 0.5;
  // Exponential lane heights clamped between MIN_LANE_H and MAX_LANE_H;
  // excess space distributed evenly so lanes converge as timeline grows.
  const EXP_R = 0.75;
  const MIN_LANE_H = 3, MAX_LANE_H = 20;
  const availLaneH = traceH - 6;
  const h0raw = totalLanes <= 1 ? availLaneH
    : availLaneH * (1 - EXP_R) / (1 - Math.pow(EXP_R, totalLanes));
  const h0 = Math.min(MAX_LANE_H, Math.max(MIN_LANE_H, h0raw));
  const laneHeights = [];
  const laneTops = [];
  let nominalTotal = 0;
  for (let i = 0; i < totalLanes; i++) {
    laneHeights[i] = Math.min(MAX_LANE_H, Math.max(MIN_LANE_H, h0 * Math.pow(EXP_R, i)));
    nominalTotal += laneHeights[i];
  }
  // Distribute leftover space equally so lanes converge as timeline grows
  const bonus = Math.max(0, (availLaneH - nominalTotal) / totalLanes);
  let acc = 0;
  for (let i = 0; i < totalLanes; i++) {
    laneHeights[i] = Math.min(MAX_LANE_H, laneHeights[i] + bonus);
    laneTops[i] = acc;
    acc += laneHeights[i];
  }
  for (let i = 0; i < totalLanes; i++) {
    const ly = traceY + 2 + laneTops[i];
    tlCtx.beginPath();
    tlCtx.moveTo(0, ly + laneHeights[i]);
    tlCtx.lineTo(w, ly + laneHeights[i]);
    tlCtx.stroke();
  }

  // Health-based color for trace spans
  function spanColor(span) {
    if (span.outcome === 'abort') return [COLORS.abort, COLORS.abort];
    const lt = span.end.linktype;
    if (lt === 'stitch') return [COLORS.stitch, COLORS.stitch];
    if (lt === 'root') return [COLORS.linked, COLORS.linked];
    return [COLORS.ok, COLORS.ok];
  }

  // Draw trace spans in depth-based swimlanes
  visibleSpanRects = [];
  let hoveredSpan = null;

  const TRACE_W = 8;
  for (const span of traceSpans) {
    if (hoverCategory) {
      if (span.category !== hoverCategory) continue;
      if (hoverCategory === 'aborted' && hoverAbortReason && span.abort_reason !== hoverAbortReason) continue;
    } else {
      if (!enabledCategories.has(span.category)) continue;
      if (span.abort_reason && !enabledAbortReasons.has(span.abort_reason)) continue;
    }
    const st = span.t0 - timeOrigin;
    if (st < viewStart - (TRACE_W / (w / vDur)) || st > viewEnd) continue;

    const x0 = ((st - viewStart) / vDur) * w;
    const bw = TRACE_W;
    const lane = Math.min(span.depth, totalLanes - 1);
    const lh = laneHeights[lane];
    const laneGap = lh > 4 ? 1 : 0.5;
    const barH = lh - laneGap;
    const by = traceY + 2 + laneTops[lane];
    const [fill, stroke] = spanColor(span);

    tlCtx.fillStyle = fill;
    tlCtx.fillRect(x0, by, bw, barH);

    visibleSpanRects.push({x: x0, y: by, w: bw, h: barH, span: span});
  }

  // Draw parent-child connection lines for the active span (selected takes priority over hovered)
  if (lastHoveredSpan || selectedSpan) {
    tlCtx.save();

    function drawConn(parentSpan, childSpan, color) {
      const pt = parentSpan.t0 - timeOrigin;
      const ct = childSpan.t0 - timeOrigin;
      if (pt > viewEnd || ct > viewEnd) return;
      const px = ((pt - viewStart) / vDur) * w + TRACE_W / 2;
      const pLane = Math.min(parentSpan.depth, totalLanes - 1);
      const py = traceY + 2 + laneTops[pLane] + laneHeights[pLane] / 2;
      const cx2 = ((ct - viewStart) / vDur) * w + TRACE_W / 2;
      const cLane = Math.min(childSpan.depth, totalLanes - 1);
      const cy = traceY + 2 + laneTops[cLane] + laneHeights[cLane] / 2;
      const midY = (py + cy) / 2;
      tlCtx.strokeStyle = color;
      tlCtx.beginPath();
      tlCtx.moveTo(px, py);
      tlCtx.bezierCurveTo(px, midY, cx2, midY, cx2, cy);
      tlCtx.stroke();
      tlCtx.fillStyle = color;
      tlCtx.beginPath(); tlCtx.arc(px, py, 2.5, 0, Math.PI * 2); tlCtx.fill();
      tlCtx.beginPath(); tlCtx.arc(cx2, cy, 2.5, 0, Math.PI * 2); tlCtx.fill();
    }

    function drawSpanTree(hs, hotColor, dimColor) {
      let root = hs;
      while (root.start.parent_id && spanByUid[traceUid(root.start.generation, root.start.parent_id)]) {
        root = spanByUid[traceUid(root.start.generation, root.start.parent_id)];
      }
      tlCtx.setLineDash([3, 3]);
      tlCtx.lineWidth = 1.5;
      const treeQueue = [root];
      while (treeQueue.length > 0) {
        const node = treeQueue.shift();
        const kids = childrenOfUid[node.uid];
        if (!kids) continue;
        for (const child of kids) {
          const isHot = (node === hs || child === hs);
          drawConn(node, child, isHot ? hotColor : dimColor);
          treeQueue.push(child);
        }
      }
    }

    // Draw selected span tree (always visible, golden)
    if (selectedSpan) {
      drawSpanTree(selectedSpan, COLORS.selectTreeLine, COLORS.selectTreeFill);
    }
    // Draw hovered span tree on top (if different from selected, cyan)
    if (lastHoveredSpan && lastHoveredSpan !== selectedSpan) {
      drawSpanTree(lastHoveredSpan, COLORS.hoverTreeLine, COLORS.hoverTreeFill);
    }

    tlCtx.restore();
    tlCtx.setLineDash([]);

    // Glow selected span
    if (selectedSpan) {
      for (const r of visibleSpanRects) {
        if (r.span === selectedSpan) {
          tlCtx.shadowColor = COLORS.selectGlow;
          tlCtx.shadowBlur = 8;
          tlCtx.strokeStyle = COLORS.select;
          tlCtx.lineWidth = 2;
          tlCtx.strokeRect(r.x, r.y, r.w, r.h);
          tlCtx.shadowBlur = 0;
          break;
        }
      }
    }
    // Highlight hovered span border
    const borderTarget = lastHoveredSpan || selectedSpan;
    if (borderTarget) {
      for (const r of visibleSpanRects) {
        if (r.span === borderTarget && borderTarget !== selectedSpan) {
          tlCtx.strokeStyle = COLORS.white;
          tlCtx.strokeRect(r.x, r.y, r.w, r.h);
          break;
        }
      }
    }
    tlCtx.restore();
  }

  // Region labels + depth labels drawn on top of boxes and hover lines
  function drawCanvasLabel(text, x, y, font) {
    tlCtx.font = font || '9px monospace';
    const tw = tlCtx.measureText(text).width;
    const pad = 2, lh = 9;
    tlCtx.fillStyle = COLORS.tooltipBg;
    tlCtx.fillRect(x - pad, y - lh, tw + pad * 2, lh + 3);
    tlCtx.fillStyle = COLORS.textMuted;
    tlCtx.fillText(text, x, y);
  }

  // Inline canvas legends — shown only while the timeline is hovered
  if (tlHovered) {
    // Helper: draw a horizontal legend row centered in a band
    function drawInlineLegend(items, centerX, midY) {
      tlCtx.font = '8px monospace';
      const swatchW = 7, swatchH = 7, gap = 4, itemGap = 10;
      // Measure total width
      let totalW = 0;
      for (const {label} of items) totalW += swatchW + gap + tlCtx.measureText(label).width + itemGap;
      totalW -= itemGap;
      let ix = centerX - totalW / 2;
      const bgPad = 5;
      tlCtx.fillStyle = COLORS.tooltipBgDim;
      tlCtx.fillRect(ix - bgPad, midY - 8, totalW + bgPad * 2, 12);
      for (const {color, label, dashed} of items) {
        tlCtx.fillStyle = color;
        if (dashed) {
          tlCtx.strokeStyle = color;
          tlCtx.lineWidth = 1;
          tlCtx.setLineDash([2, 2]);
          tlCtx.strokeRect(ix, midY - swatchH + 1, swatchW, swatchH);
          tlCtx.setLineDash([]);
        } else {
          tlCtx.fillRect(ix, midY - swatchH + 1, swatchW, swatchH);
        }
        tlCtx.fillStyle = COLORS.textMid;
        tlCtx.fillText(label, ix + swatchW + gap, midY);
        ix += swatchW + gap + tlCtx.measureText(label).width + itemGap;
      }
    }
  }
  // Depth labels: root trace, d1, d2, d3, d.., d{maxDepth}
  {
    const maxDepth = totalLanes - 1;
    // Build list of lane indices to label
    const labelLanes = []; // {lane, text}
    labelLanes.push({lane: 0, text: 'root trace'});
    for (let i = 1; i <= Math.min(3, maxDepth); i++) {
      labelLanes.push({lane: i, text: 'd' + i});
    }
    if (maxDepth > 4) {
      // insert ellipsis after d3 (not a real lane, just drawn at lane 4 position)
      labelLanes.push({lane: 4, text: 'd\u2026'});
    }
    if (maxDepth > 3) {
      labelLanes.push({lane: maxDepth, text: 'd' + maxDepth});
    }
    tlCtx.font = '8px monospace';
    for (const {lane, text} of labelLanes) {
      const li = Math.min(lane, totalLanes - 1);
      const ly = traceY + 2 + laneTops[li] + laneHeights[li] / 2 + 3;
      const tw = tlCtx.measureText(text).width;
      tlCtx.fillStyle = COLORS.tooltipBg;
      tlCtx.fillRect(0, ly - 8, tw + 4, 11);
      tlCtx.fillStyle = COLORS.textDim;
      tlCtx.fillText(text, 2, ly);
    }
  }

  // Draw FLUSH lines (prominent, full height of trace region)
  // Drawn last so they sit on top of everything else
  if (enabledCategories.has('flush')) {
    tlCtx.save();
    tlCtx.setLineDash([5, 4]);
    tlCtx.strokeStyle = COLORS.abort;
    tlCtx.lineWidth = 2;
    tlCtx.font = 'bold 9px monospace';
    tlCtx.fillStyle = COLORS.abort;
    for (const ft of flushTimes) {
      const t = ft - timeOrigin;
      if (t < viewStart || t > viewEnd) continue;
      const fx = ((t - viewStart) / vDur) * w;
      // Semi-transparent band
      tlCtx.fillStyle = COLORS.flushBand;
      tlCtx.fillRect(fx - 4, traceY, 8, traceH);
      // Dashed line
      tlCtx.strokeStyle = COLORS.abort;
      tlCtx.beginPath();
      tlCtx.moveTo(fx, traceY);
      tlCtx.lineTo(fx, traceY + traceH);
      tlCtx.stroke();
      // Label in VM area with black background
      tlCtx.font = 'bold 9px monospace';
      const txt = 'FLUSH';
      const tw = tlCtx.measureText(txt).width;
      tlCtx.fillStyle = '#000';
      tlCtx.fillRect(fx + 2, 2, tw + 4, 11);
      tlCtx.fillStyle = COLORS.abort;
      tlCtx.fillText(txt, fx + 4, 11);
    }
    tlCtx.restore();
  }


  // Schedule panel updates (debounced) — avoids rebuilding DOM on every canvas frame
  const currentFilterStateKey = Array.from(enabledStates).sort().join(',') + '|' + Array.from(enabledSections).sort().join(',') + '|' + (hoverState || '') + '|' + (hoverSection || '') + '|' + (hoverCategory || '') + '|' + (hoverAbortReason || '');
  const rangeKey = currentRange[0].toFixed(6) + ':' + currentRange[1].toFixed(6);
  if (rangeKey !== lastPanelRangeKey || currentFilterStateKey !== lastFilterStateKey) {
    lastPanelRangeKey = rangeKey;
    lastFilterStateKey = currentFilterStateKey;
    schedulePanelUpdate(currentRange[0], currentRange[1]);
    scheduleFlamegraph(currentRange[0], currentRange[1]);
  }
}

function tlXToTime(clientX) {
  const rect = getTlRect();
  const frac = (clientX - rect.left) / rect.width;
  const t = viewStart + frac * (viewEnd - viewStart);
  return Math.max(0, Math.min(timeDuration, t));
}

// --- Timeline tooltip ---
function formatTooltip(e) {
  const t = (e.time - timeOrigin).toFixed(6);
  let s = `<b>${e.type}</b>  <span style="color:${COLORS.textDimmer}">${t}s</span>`;

  switch(e.type) {
    case 'sample': {
      const stateLabel = VM_STATE_LABELS[e.vm_state] || e.vm_state || '?';
      const stateColor = VM_STATE_COLORS[e.vm_state] || COLORS.textBright;
      s += `\n<span style="color:${stateColor}">● ${stateLabel}</span>`;
      if (e.section_path) s += `\nSection: ${e.section_path}`;
      break;
    }
    case 'trace_start':
      s += `\nTrace <b>#${e.id}</b>`;
      if (e.parent_id) s += `  (side of #${e.parent_id} exit ${e.exit_id})`;
      if (e.func_info) s += `\nLocation: ${funcInfoLink(e.func_info)}`;
      break;
    case 'trace_stop':
      s += `\nTrace <b>#${e.id}</b> completed`;
      if (e.linktype) s += `  link: ${e.linktype}`;
      if (e.link_id) s += ` → #${e.link_id}`;
      if (e.ir_count) s += `\nIR: ${e.ir_count} instructions, ${e.exit_count || 0} exits`;
      if (e.func_info) s += `\nLocation: ${funcInfoLink(e.func_info)}`;
      break;
    case 'trace_abort':
      s += `\nTrace <b>#${e.id}</b> aborted`;
      s += `\n<span style="color:${COLORS.abort}">${e.abort_reason || '?'}</span>`;
      if (e.func_info) s += `\nLocation: ${funcInfoLink(e.func_info)}`;
      break;
    case 'trace_flush':
      s += `\n<span style="color:${COLORS.abort}">All traces flushed — recompilation storm</span>`;
      break;
    case 'section_start':
      s += `\nSection: <b>${e.name}</b>`;
      if (e.section_path) s += `\nPath: ${e.section_path}`;
      break;
    case 'section_end':
      s += `\nSection end: <b>${e.name}</b>`;
      break;
  }
  return s;
}

function formatSpanTooltip(span) {
  const duration = span.t1 - span.t0;
  const dStr = duration < 0.001 ? (duration * 1e6).toFixed(0) + 'µs' : (duration * 1000).toFixed(2) + 'ms';
  const t0 = (span.t0 - timeOrigin).toFixed(6);
  let s = '';
  if (span.outcome === 'stop') {
    const lt = span.end.linktype || '?';
    const ltColor = lt === 'stitch' ? COLORS.stitch : lt === 'root' ? COLORS.linked : COLORS.ok;
    s += `<b style="color:${ltColor}">Trace #${span.id}</b>  <span style="color:${COLORS.textDimmer}">${t0}s</span>  ${dStr}`;
    const e = span.end;
    if (e.linktype) s += `\nLink: <b>${e.linktype}</b>`;
    if (e.link_id) s += ` → #${e.link_id}`;
    if (e.ir_count) s += `\nIR: ${e.ir_count} instructions, ${e.exit_count || 0} exits`;
  } else {
    s += `<b style="color:${COLORS.abort}">Trace #${span.id} aborted</b>  <span style="color:${COLORS.textDimmer}">${t0}s</span>  ${dStr}`;
    s += `\n<span style="color:${COLORS.abort}">${span.end.abort_reason || '?'}</span>`;
  }
  if (span.start.func_info) s += `\n ${funcInfoLink(span.start.func_info)}`;
  if (span.start.parent_id) s += `\n↑ parent #${span.start.parent_id} (exit ${span.start.exit_id})`;
  if (span.end.func_info && span.end.func_info !== span.start.func_info) s += `\n   → ${funcInfoLink(span.end.func_info)}`;
  const kids = childrenOfUid[span.uid];
  if (kids && kids.length > 0) {
    const okKids = kids.filter(k => k.outcome === 'stop').length;
    const abKids = kids.length - okKids;
    s += `\n↓ ${kids.length} side trace${kids.length > 1 ? 's' : ''}`;
    if (abKids > 0) s += ` <span style="color:${COLORS.abort}">(${abKids} aborted)</span>`;
  }
  s += `\n<span style="color:${COLORS.textVeryDim}">depth: ${span.depth}</span>`;
  return s;
}

tlCanvas.addEventListener('mousedown', (ev) => {
  if (ev.button !== 0) return; // Only handle left clicks

  // Force a redraw/measurement if sampleH or rect is somehow stale
  if (sampleH === 0) drawTimeline();
  const rect = getTlRect();
  const mouseY = ev.clientY - rect.top;
  const inSampleRegion = mouseY < sampleH;

  hideTooltip();

  if (inSampleRegion) {
    // VM state area — draw selection
    dragMode = 'select';
    selStart = tlXToTime(ev.clientX);
    selEnd = selStart;
    selOverlay.style.display = 'block';
    updateSelOverlay();
  } else {
    // Trace area — pan the view (or click to select a span)
    dragMode = 'pan';
    panStartX = ev.clientX;
    panViewStart0 = viewStart;
    panViewEnd0 = viewEnd;
    tlCanvas.style.cursor = 'grabbing';
    // Use the already-accurate hover result as the click candidate
    panClickSpanCandidate = lastHoveredSpan;
  }
});

tlCanvas.addEventListener('mousemove', (ev) => {
  if (dragMode) return;

  const rect = tlCanvas.getBoundingClientRect();
  const t = tlXToTime(ev.clientX);
  const vDur = viewEnd - viewStart || 1;
  const threshold = (vDur / rect.width) * 8;
  const mouseX = ev.clientX - rect.left;
  const mouseY = ev.clientY - rect.top;
  const h = rect.height;
  const inSampleRegion = mouseY < sampleH;

  let tooltipContent = null;

  if (inSampleRegion) {
    // Find closest sample
    let closest = null;
    let minDist = threshold;
    for (const e of EVENTS) {
      if (e.type !== 'sample') continue;
      const et = e.time - timeOrigin;
      const d = Math.abs(et - t);
      if (d < minDist) { minDist = d; closest = e; }
    }
    if (closest) tooltipContent = formatTooltip(closest);
  } else {
    // Hit-test trace span rects
    for (let i = visibleSpanRects.length - 1; i >= 0; i--) {
      const r = visibleSpanRects[i];
      if (mouseX >= r.x && mouseX <= r.x + r.w && mouseY >= r.y && mouseY <= r.y + r.h) {
        tooltipContent = formatSpanTooltip(r.span);
        if (lastHoveredSpan !== r.span) {
          lastHoveredSpan = r.span;
          syncTraceListHighlight(r.span);
          drawTimeline();
        }
        break;
      }
    }
    if (!tooltipContent && lastHoveredSpan) {
      lastHoveredSpan = null;
      syncTraceListHighlight(null);
      drawTimeline();
    }
    // Fallback: nearest trace event by time
    if (!tooltipContent) {
      let closest = null;
      let minDist = threshold;
      for (const e of EVENTS) {
        if (!e.type.startsWith('trace_')) continue;
        if (e.type !== 'trace_flush') continue;
        const et = e.time - timeOrigin;
        const d = Math.abs(et - t);
        if (d < minDist) { minDist = d; closest = e; }
      }
      if (closest) tooltipContent = formatTooltip(closest);
    }
  }

  if (tooltipContent) {
    showTooltip(tooltipContent, Math.min(ev.clientX + 15, window.innerWidth - 520), ev.clientY + 15);
    tlCanvas.style.cursor = 'pointer';
  } else {
    hideTooltip();
    tlCanvas.style.cursor = inSampleRegion ? 'crosshair' : 'grab';
  }
});

tlCanvas.addEventListener('mouseenter', () => {
  tlHovered = true;
  drawTimeline();
});

tlCanvas.addEventListener('mouseleave', () => {
  tlHovered = false;
  if (!dragMode) {
    hideTooltip();
    tlCanvas.style.cursor = 'crosshair';
    if (lastHoveredSpan) {
      lastHoveredSpan = null;
      syncTraceListHighlight(null);
      drawTimeline();
    }
  }
});

window.addEventListener('mousemove', (ev) => {
  if (!dragMode) return;
  if (dragMode === 'select') {
    lastSelectX = ev.clientX;
    selEnd = tlXToTime(ev.clientX);
    
    // Auto-scroll logic
    const rect = getTlRect();
    const margin = 25;
    const relX = ev.clientX - rect.left;
    
    if (relX < margin || relX > rect.width - margin) {
      if (!autoScrollTimer) {
        autoScrollTimer = setInterval(() => {
          const rect = getTlRect();
          const relX = lastSelectX - rect.left;
          const vDur = viewEnd - viewStart;
          let dt = 0;
          
          if (relX < margin) {
            dt = -vDur * 0.05;
          } else if (relX > rect.width - margin) {
            dt = vDur * 0.05;
          }
          
          const newStart = Math.max(0, Math.min(timeDuration - vDur, viewStart + dt));
          if (newStart !== viewStart) {
            viewStart = newStart;
            viewEnd = newStart + vDur;
            selEnd = tlXToTime(lastSelectX);
            refreshView(viewStart, viewEnd);
          }
        }, 30);
      }
    } else if (autoScrollTimer) {
      clearInterval(autoScrollTimer);
      autoScrollTimer = null;
    }
    
    updateSelOverlay();
  } else if (dragMode === 'pan') {
    const rect = getTlRect();
    const dx = ev.clientX - panStartX;
    const vDur = panViewEnd0 - panViewStart0 || 1;
    const dt = -(dx / rect.width) * vDur;
    let newStart = panViewStart0 + dt;
    let newEnd = panViewEnd0 + dt;
    if (newStart < 0) { newEnd -= newStart; newStart = 0; }
    if (newEnd > timeDuration) { newStart -= (newEnd - timeDuration); newEnd = timeDuration; }
    viewStart = Math.max(0, newStart);
    viewEnd = Math.min(timeDuration, newEnd);
    refreshView(viewStart, viewEnd);
  }
});

window.addEventListener('mouseup', () => {
  if (!dragMode) return;
  const mode = dragMode;
  dragMode = null;
  if (autoScrollTimer) {
    clearInterval(autoScrollTimer);
    autoScrollTimer = null;
  }
  if (mode === 'select') {
    if (selStart !== null && selEnd !== null) {
      let lo = Math.min(selStart, selEnd), hi = Math.max(selStart, selEnd);
      // If selection is too small (e.g. a single click), reset selection to full view
      if (hi - lo < 0.000001) {
        selStart = viewStart; selEnd = viewEnd;
        refreshView(viewStart, viewEnd, true);
      } else {
        updateSelOverlay();
        drawFlamegraph(lo, hi);
      }
    }
  } else if (mode === 'pan') {
    tlCanvas.style.cursor = 'grab';
    // If the view didn't actually move it's a click — select/deselect the span
    const actualMoved = Math.abs(viewStart - panViewStart0) > 0.000001 ||
                        Math.abs(viewEnd - panViewEnd0) > 0.000001;
    if (!actualMoved && panClickSpanCandidate) {
      const span = panClickSpanCandidate;
      selectedSpan = (selectedSpan === span) ? null : span;
      panClickSpanCandidate = null;
      drawTimeline();
      syncTraceListHighlight(selectedSpan);
      schedulePanelUpdate(selStart, selEnd);
    }
    panClickSpanCandidate = null;
  }
});

function updateSelOverlay() {
  const vDur = viewEnd - viewStart || 1;
  const isZoomed = (viewStart > 0.0001 || viewEnd < timeDuration - 0.0001);
  const btnReset = document.getElementById('btn-reset');
  if (btnReset) btnReset.style.display = isZoomed ? 'block' : 'none';

  if (selStart === null || selEnd === null) {
    selOverlay.style.display = 'none';
    return;
  }
  const rect = getTlRect();
  const lo = Math.min(selStart, selEnd), hi = Math.max(selStart, selEnd);
  const lx = ((lo - viewStart) / vDur) * rect.width;
  const rx = ((hi - viewStart) / vDur) * rect.width;

  selOverlay.style.left = lx + 'px';
  selOverlay.style.width = Math.max(1, rx - lx) + 'px';
  selOverlay.style.display = 'block';

  const btnZoom = document.getElementById('btn-zoom-sel');
  const isFullSelection = (lo <= viewStart + 0.0001 && hi >= viewEnd - 0.0001);
  if (btnZoom) {
    const sWidth = Math.max(1, rx - lx);
    btnZoom.style.display = (hi - lo > 0.0001 && sWidth > 40 && !isFullSelection) ? 'block' : 'none';
  }

  // Exception for 0-100% full selection
  const isFull = (lx <= 0 && rx >= rect.width);
  selOverlay.style.background = isFull ? 'transparent' : 'var(--accent-dim)';

  // Time labels with clamping
  const startEl = document.getElementById('sel-t-start');
  const endEl = document.getElementById('sel-t-end');

  if (startEl) {
    startEl.textContent = lo.toFixed(4) + 's';
    const w = startEl.offsetWidth;
    let offsetX = -w / 2;
    if (lx + offsetX < 0) offsetX = -lx;
    if (lx + offsetX + w > rect.width) offsetX = rect.width - lx - w;
    startEl.style.transform = `translate(${offsetX}px, 2px)`; // Moved inside VM area
  }
  if (endEl) {
    endEl.textContent = hi.toFixed(4) + 's';
    const w = endEl.offsetWidth;
    let offsetX = -w / 2;
    const absRx = rx;
    if (absRx + offsetX < 0) offsetX = -absRx;
    if (absRx + offsetX + w > rect.width) offsetX = rect.width - absRx - w;
    endEl.style.transform = `translate(${offsetX}px, 2px)`; // Moved inside VM area
  }

  schedulePanelUpdate(lo, hi);
}

// --- Options Dropdown ---
const btnOptions = document.getElementById('btn-toggle-options');
const optionsDropdown = document.getElementById('options-dropdown');
const cbHoverPreview = document.getElementById('cb-hover-preview');
const cbHoverIndicator = document.getElementById('cb-hover-preview-indicator');

btnOptions.addEventListener('click', (ev) => {
  ev.stopPropagation();
  optionsDropdown.classList.toggle('open');
});

document.addEventListener('click', (ev) => {
  if (!optionsDropdown.contains(ev.target) && ev.target !== btnOptions) {
    optionsDropdown.classList.remove('open');
  }
});

cbHoverPreview.parentElement.addEventListener('click', () => {
  cbHoverPreview.checked = !cbHoverPreview.checked;
  cbHoverIndicator.textContent = cbHoverPreview.checked ? '☑' : '☐';
  drawTimeline();
});

document.getElementById('btn-reset').addEventListener('click', () => {
  viewStart = 0; viewEnd = timeDuration;
  selStart = 0; selEnd = timeDuration;
  refreshView(0, timeDuration, true);
});

document.getElementById('btn-zoom-sel').addEventListener('click', () => {
  if (selStart !== null && selEnd !== null) {
    const lo = Math.min(selStart, selEnd), hi = Math.max(selStart, selEnd);
    if (hi - lo > 0.0001) {
      viewStart = lo; viewEnd = hi;
      selStart = viewStart; selEnd = viewEnd;
      refreshView(viewStart, viewEnd, true);
    }
  }
});

// Mouse wheel zoom on timeline
tlCanvas.addEventListener('wheel', (ev) => {
  ev.preventDefault();
  const zoomFactor = ev.deltaY > 0 ? 1.2 : 1/1.2;
  const mouseT = tlXToTime(ev.clientX);
  const newStart = mouseT - (mouseT - viewStart) * zoomFactor;
  const newEnd = mouseT + (viewEnd - mouseT) * zoomFactor;
  viewStart = Math.max(0, newStart);
  viewEnd = Math.min(timeDuration, newEnd);
  // Canvas redraws immediately; panels + flamegraph are debounced to avoid
  // rebuilding expensive DOM on every wheel tick.
  refreshView(viewStart, viewEnd);
}, {passive: false});

// --- Resize handle helper ---
function makeResizable(handle, minH, getH, setH) {
  let dragging = false, startY = 0, startH = 0;
  handle.addEventListener('mousedown', (ev) => {
    dragging = true; startY = ev.clientY; startH = getH();
    handle.classList.add('dragging'); ev.preventDefault();
  });
  window.addEventListener('mousemove', (ev) => {
    if (!dragging) return;
    setH(Math.max(minH, startH + (ev.clientY - startY)));
  });
  window.addEventListener('mouseup', () => {
    if (dragging) { dragging = false; handle.classList.remove('dragging'); }
  });
}

// --- Timeline resize handle ---
const tlContainer = document.getElementById('timeline-container');
const tracePanel = document.getElementById('trace-panel');
const TRACE_PANEL_DEFAULT_H = 280;
let tracePanelH = TRACE_PANEL_DEFAULT_H;
tracePanel.style.height = tracePanelH + 'px';

makeResizable(document.getElementById('trace-panel-resize-handle'), 60,
  () => tracePanelH,
  (h) => { tracePanelH = h; tracePanel.style.height = h + 'px'; }
);

function computeDefaultTimelineH() {
  const r = 0.75, minH = 3, maxH = 20;
  // Sum of clamped exponential lane heights
  let lanesH = 0;
  for (let i = 0; i < totalLanes; i++) lanesH += Math.min(maxH, Math.max(minH, maxH * Math.pow(r, i)));
  // sampleH capped at 35px; traceY = sampleH+4; traceH = lanesH+6
  return Math.max(80, Math.round(35 + 4 + lanesH + 6));
}

makeResizable(document.getElementById('timeline-resize-handle'), 25,
  () => timelineContainerH,
  (h) => { timelineContainerH = h; tlContainer.style.height = h + 'px'; invalidateTlRect(); drawTimeline(); updateSelOverlay(); }
);

// --- Flamegraph ---
const fgCanvas = document.getElementById('flamegraph-canvas');
const fgCtx = fgCanvas.getContext('2d');
let fgRects = [];

function buildFlamegraph(tStart, tEnd) {
  const stacks = [];
  const currentEnabledStates = new Set(enabledStates);
  const currentEnabledSections = new Set(enabledSections);

  for (const e of EVENTS) {
    if (e.type !== 'sample') continue;
    const t = e.time - timeOrigin;
    if (t < tStart || t > tEnd) continue;
    if (!e.stack) continue;
    // Filter out samples belonging to disabled sections or non-hovered state/section
    if (hoverState || hoverSection) {
      if (hoverState && e.vm_state !== hoverState) continue;
      if (hoverSection && e.section_path !== hoverSection) continue;
    } else {
      if (!currentEnabledStates.has(e.vm_state)) continue;
      if (e.section_path) {
        const rootSec = e.section_path.split(' > ')[0];
        if (ALL_SECTIONS.includes(rootSec) && !currentEnabledSections.has(rootSec)) continue;
      } else {
        if (!currentEnabledSections.has(SECTION_OTHER)) continue;
      }
    }
    const lines = e.stack.split('\n').filter(l => l.trim().length > 0);
    const reversed = lines.slice().reverse();
    stacks.push({frames: reversed, section: e.section_path || ''});
  }

  if (stacks.length === 0) return {root: {children: {}, count: 0, name: 'all'}, maxDepth: 0, totalSamples: 0};

  const root = {name: 'all', children: {}, count: stacks.length, _self: 0};
  let maxDepth = 0;

  for (const s of stacks) {
    let node = root;
    const frames = s.section ? [s.section, ...s.frames] : s.frames;
    for (let i = 0; i < frames.length; i++) {
      const frame = frames[i].trim();
      if (!frame) continue;
      if (!node.children[frame]) {
        node.children[frame] = {name: frame, children: {}, count: 0, _self: 0};
      }
      node.children[frame].count++;
      node = node.children[frame];
      if (i + 1 > maxDepth) maxDepth = i + 1;
    }
    node._self++;
  }

  return {root, maxDepth, totalSamples: stacks.length};
}

const FG_ROW_HEIGHT = 20;
const FG_FONT_SIZE = 11;
const FG_MIN_WIDTH_PX = 2;

function drawFlamegraph(tStart, tEnd) {
  const container = document.getElementById('flamegraph-container');
  if (!container || !container.classList.contains('open')) return;
  const {root, maxDepth, totalSamples} = buildFlamegraph(tStart, tEnd);
  const containerW = fgCanvas.parentElement.clientWidth;
  const canvasH = Math.max(400, (maxDepth + 2) * FG_ROW_HEIGHT + 40);

  setupCanvas(fgCanvas, containerW, canvasH);

  fgCtx.fillStyle = COLORS.bgDeep;
  fgCtx.fillRect(0, 0, containerW, canvasH);

  if (totalSamples === 0) {
    fgCtx.fillStyle = COLORS.textDimmer;
    fgCtx.font = '13px monospace';
    fgCtx.fillText('No samples in selected range', 20, 30);
    fgRects = [];
    return;
  }

  fgCtx.font = FG_FONT_SIZE + 'px monospace';
  fgRects = [];

  const yOffset = 8;
  const totalWidth = containerW - 16;
  const xOffset = 8;

  function colorForFrame(name) {
    let h = 0;
    for (let i = 0; i < name.length; i++) h = ((h << 5) - h + name.charCodeAt(i)) | 0;
    h = Math.abs(h);
    const hue = (h % 40) + 10;
    const sat = 50 + (h % 30);
    const lit = 45 + (h % 20);
    return `hsl(${hue}, ${sat}%, ${lit}%)`;
  }

  function drawNode(node, depth, xStart, xEnd) {
    const w = xEnd - xStart;
    if (w < FG_MIN_WIDTH_PX) return;

    const y = yOffset + depth * FG_ROW_HEIGHT;
    const rectH = FG_ROW_HEIGHT;

    fgCtx.fillStyle = depth === 0 ? COLORS.border : colorForFrame(node.name);
    // Draw rect that is 1px smaller than its available space to create a 1px gap
    fgCtx.fillRect(xStart, y, w - 1, rectH - 1);

    if (w > 30) {
      fgCtx.fillStyle = COLORS.white;
      fgCtx.font = FG_FONT_SIZE + 'px monospace';
      const label = node.name;
      const textW = fgCtx.measureText(label).width;
      if (textW < w - 6) {
        fgCtx.fillText(label, xStart + 3, y + rectH - 5);
      } else {
        let truncated = label;
        while (truncated.length > 1 && fgCtx.measureText(truncated + '…').width > w - 6) {
          truncated = truncated.slice(0, -1);
        }
        fgCtx.fillText(truncated + '…', xStart + 3, y + rectH - 5);
      }
    }

    fgRects.push({
      x: xStart, y: y, w: w - 1, h: rectH - 1,
      label: node.name,
      count: node.count, self: node._self, total: root.count
    });

    const kids = Object.values(node.children).sort((a, b) => b.count - a.count);
    let cx = xStart;
    for (const child of kids) {
      const cw = (child.count / node.count) * w;
      drawNode(child, depth + 1, cx, cx + cw);
      cx += cw;
    }
  }

  drawNode(root, 0, xOffset, xOffset + totalWidth);
}

// Tooltip on flamegraph
fgCanvas.addEventListener('mousemove', (ev) => {
  const rect = fgCanvas.getBoundingClientRect();
  const mx = ev.clientX - rect.left;
  const my = ev.clientY - rect.top;

  let hit = null;
  for (let i = fgRects.length - 1; i >= 0; i--) {
    const r = fgRects[i];
    if (mx >= r.x && mx <= r.x + r.w && my >= r.y && my <= r.y + r.h) {
      hit = r; break;
    }
  }

  if (hit) {
    const pct = ((hit.count / hit.total) * 100).toFixed(1);
    const selfPct = ((hit.self / hit.total) * 100).toFixed(1);
    showTooltip(`<b>${hit.label}</b>\n${hit.count} samples (${pct}%)\nself: ${hit.self} (${selfPct}%)`, ev.clientX + 12, ev.clientY - 10);
    // Show pointer cursor if the frame is navigable
    fgCanvas.style.cursor = hit.label.match(/^.+:[0-9]+$/) ? 'pointer' : 'default';
  } else {
    hideTooltip();
    fgCanvas.style.cursor = 'default';
  }
});

fgCanvas.addEventListener('click', (ev) => {
  const rect = fgCanvas.getBoundingClientRect();
  const mx = ev.clientX - rect.left;
  const my = ev.clientY - rect.top;
  for (let i = fgRects.length - 1; i >= 0; i--) {
    const r = fgRects[i];
    if (mx >= r.x && mx <= r.x + r.w && my >= r.y && my <= r.y + r.h) {
      const link = funcInfoLink(r.label);
      // funcInfoLink returns an <a> tag only when path:line is detected
      const m = r.label.match(/^(.+):([0-9]+)$/);
      if (m) {
        const [, filePath, line] = m;
        window.location.href = FILE_URL_TEMPLATE.replace(/\$\{path\}/g, filePath).replace(/\$\{line\}/g, line);
      }
      break;
    }
  }
});

fgCanvas.addEventListener('mouseleave', () => { hideTooltip(); });

// --- Init ---
timelineContainerH = computeDefaultTimelineH();
tlContainer.style.height = timelineContainerH + 'px';

// Trigger a sync layout pass and first draw
requestAnimationFrame(() => {
  invalidateTlRect();
  drawTimeline();
  updateSelOverlay();
  refreshView(0, timeDuration, true);
});

// Pie chart hover — highlight matching VM state in timeline
const vmPieCanvas = document.getElementById('vm-pie-canvas');
vmPieCanvas.addEventListener('mousemove', (ev) => {
  const rect = vmPieCanvas.getBoundingClientRect();
  const size = 72;
  const cx = size / 2, cy = size / 2;
  const mx = (ev.clientX - rect.left) * (size / rect.width);
  const my = (ev.clientY - rect.top)  * (size / rect.height);
  const dx = mx - cx, dy = my - cy;
  const dist = Math.sqrt(dx*dx + dy*dy);
  const outerR = size / 2 - 3;
  if (dist > outerR + 4) {
    if (pieHoveredState !== null) { pieHoveredState = null; drawTimeline(); drawVmPie(selStart, selEnd); }
    return;
  }
  let a = Math.atan2(dy, dx);
  // normalize to same start (-PI/2) as drawing code
  if (a < -Math.PI / 2) a += Math.PI * 2;
  let found = null;
  for (const sl of pieSlices) {
    let a0 = sl.a0, a1 = sl.a1;
    if (a0 < -Math.PI / 2) { a0 += Math.PI * 2; a1 += Math.PI * 2; }
    if (a >= a0 && a <= a1) { found = sl.state; break; }
  }
  if (found !== pieHoveredState) {
    pieHoveredState = found;
    drawTimeline();
    drawVmPie(selStart, selEnd);
  }
});
vmPieCanvas.addEventListener('mouseleave', () => {
  if (pieHoveredState !== null) {
    pieHoveredState = null;
    drawTimeline();
    drawVmPie(selStart, selEnd);
  }
});

window.addEventListener('resize', () => { invalidateTlRect(); refreshView(viewStart, viewEnd, true); });
refreshView(0, timeDuration, true);
}); // end DOMContentLoaded
</script>
</body>
</html>
]==]
return Profiler