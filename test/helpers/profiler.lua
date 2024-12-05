local jit_profiler = require("test.helpers.jit_profiler")
local trace_tracker = require("test.helpers.jit_trace_track")
local profiler = {}
local should_run = true
local stop_profiler
local stop_tracing

function profiler.Start()
	if not has_jit then return end

	stop_profiler = jit_profiler.Start(
		{
			mode = "line",
			sampling_rate = 1,
			depth = 2, -- a high depth will show where time is being spent at a higher level in top level functions which is kinda useless
			sample_threshold = 100,
		}
	)
	stop_tracer = trace_tracker.Start()
end

function profiler.Stop()
	if not has_jit then return end

	if stop_tracer then
		local traces, aborted = stop_tracer()
		print("\nluajit traces that were aborted and stitched:")
		print(trace_tracker.ToStringProblematicTraces(traces, aborted))
	end

	if stop_profiler then
		print("\nprofiler statistics:")
		print(
			"I = interpreter, G = garbage collection, J = busy tracing, N = native / tracing completed:"
		)
		print(stop_profiler())
	end
end

return profiler
