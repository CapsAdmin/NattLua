require("nattlua.other.jit_options")()
local trace_track = require("nattlua.other.jit_trace_track")
trace_track.Start()

if true then
	local nl = require("nattlua.compiler")
	local profiler = require("nattlua.other.jit_profiler2")
	local code = io.open("/home/caps/projects/NattLua/examples/projects/gmod/nattlua/glua_base.nlua", "r"):read("*all")

	for i = 1, 5 do
		local c = nl.New(code)
		c:Parse()
		c:Analyze()
	end
end

local traces, aborted = trace_track.Stop()
trace_track.DumpProblematicTraces(traces, aborted)