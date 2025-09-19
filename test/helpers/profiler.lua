local jit_profiler = require("test.helpers.jit_profiler")
local line_profiler = require("test.helpers.line_profiler")
local trace_tracker = require("test.helpers.jit_trace_track")
local profiler = {}
local should_run = true
local stop_profiler
local stop_tracing

function profiler.Start(mode)
	if mode == "trace" then
		stop_tracer = trace_tracker.Start()
	elseif mode == "instrumental" then
		stop_profiler = line_profiler.Start()
	else
		stop_profiler = jit_profiler.Start(
			{
				mode = "line",
				sampling_rate = 10,
				depth = 1, -- a high depth will show where time is being spent at a higher level in top level functions which is kinda useless
				threshold = 20,
			}
		)
stop_tracer = trace_tracker.Start()
	end
end

function profiler.Stop()
	if stop_tracer then
		local traces, aborted = stop_tracer()
		local str = trace_tracker.ToStringProblematicTraces(traces, aborted)

		if #str > 0 then
			io.write("\nluajit traces that were aborted and stitched:\n")
			io.write(str, "\n")
		else
			io.write("\nno problematic traces found\n")
		end
	end

	if stop_profiler then io.write(stop_profiler()) end
end

return profiler
