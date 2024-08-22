local has_jit, jit_profiler = pcall(require, "nattlua.other.jit_profiler")
local profiler = {}
local should_run = true

if _G.ON_EDITOR_SAVE or not has_jit then should_run = false end

function profiler.Start()
	if not should_run then return end

	jit_profiler.EnableStatisticalProfiling(true)
	jit_profiler.EnableTraceAbortLogging(true)
end

function profiler.Stop()
	if not should_run then return end

	local stats_filter = {
		{title = "all", filter = nil},
		{title = "lexer", filter = "nattlua/lexer"},
		{title = "parser", filter = "nattlua/parser"},
		{title = "types", filter = "nattlua/types"},
		{title = "analyzer", filter = "nattlua/analyzer"},
	}
	jit_profiler.EnableTraceAbortLogging(false)
	jit_profiler.EnableStatisticalProfiling(false)
	jit_profiler.PrintTraceAborts(500)

	for i, v in ipairs(stats_filter) do
		jit_profiler.PrintStatistical(500, v.title, v.filter)
	end
end

return profiler
