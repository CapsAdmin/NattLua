local line_profiler = require("test.helpers.line_profiler")--[[#: {Start = function=(any)>(any)}]]
local jit_profiler = require("test.helpers.jit_profiler")
local TraceTrack = require("test.helpers.jit_trace_track")
local get_time = require("test.helpers.get_time")
local profile_stop, profile_report
local trace_tracker
local profiler = {}
local f

local function save_progress()
	if trace_tracker then
		f:write(trace_tracker:GetReportProblematicTraces() .. "\n")
	end

	if profile_report then f:write(profile_report() .. "\n") end

	f:flush()
	f:seek("set", 0)
end

function profiler.Start(id)
	id = id or "global"
	time_start = get_time()
	trace_tracker = TraceTrack.New()
	trace_tracker:Start()
	profile_stop, profile_report = jit_profiler.Start()
	f = assert(io.open("profile_summary_" .. id .. ".md", "w"))
--timer.Repeat("debug", 1, math.huge, save_progress)
end

function profiler.Stop()
	save_progress()

	do -- store total time
		f:seek("end", 0)
		local total_time = get_time() - time_start

		if f then
			f:write("## Total time: " .. string.format("%.2f", total_time) .. " seconds\n")
		end
	end

	f:close()
	profile_stop()

	if trace_tracker then trace_tracker:Stop() end
--timer.RemoveTimer("debug")
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

return profiler