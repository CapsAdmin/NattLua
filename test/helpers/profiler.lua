local jit_profiler = require("test.helpers.jit_profiler")
local line_profiler = require("test.helpers.line_profiler")--[[#: {Start = function=(any)>(any)}]]
local trace_tracker = require("test.helpers.jit_trace_track")
local get_time = require("test.helpers.get_time")
local profiler = {}
local should_run = true
local stop_profiler
local stop_tracing

function profiler.Start(mode--[[#: string | nil]], whitelist--[[#: List<|string|> | nil]])
	if mode == "trace" then
		stop_tracer = trace_tracker.Start()
	elseif mode == "instrumental" then
		stop_profiler = line_profiler.Start(whitelist)
	else
		stop_tracer = trace_tracker.Start()
		stop_profiler = jit_profiler.Start(
			{
				mode = "line",
				sampling_rate = 1,
				depth = 1, -- a high depth will show where time is being spent at a higher level in top level functions which is kinda useless
				threshold = 20,
			}
		)
	end
end

local simple_times = {}
local simple_stack = {}

function profiler.StartSection(name--[[#: string]])
	simple_times[name] = simple_times[name] or {total = 0}
	simple_times[name].time = get_time()
	table.insert(simple_stack, name)

	if not stop_profiler then return end

	jit_profiler.StartSection(name)
end

function profiler.StopSection()
	local name = table.remove(simple_stack)
	simple_times[name].total = simple_times[name].total + (get_time() - simple_times[name].time)

	if not stop_profiler then return end

	jit_profiler.StopSection()
end

function profiler.GetSimpleSections()
	return simple_times
end

function profiler.Stop()
	if stop_profiler then io.write(stop_profiler()) end

	if stop_tracer then
		local traces, aborted = stop_tracer()
		local str = trace_tracker.ToStringTraceInfo(traces, aborted)
		io.write(str or "")
	end
end

return profiler
