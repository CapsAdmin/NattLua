do
	return
end

math.randomseed(1)
local trace_track = require("test.helpers.jit_trace_track")
local jit_options = require("nattlua.other.jit_options")

local function test(opt, func)
	jit_options.Set(opt)
	trace_track.Start()
	jit.flush(true, true)
	func()
	local traces, aborted = trace_track.Stop()
	jit.flush(true, true)
	jit_options.Set()
	return traces, aborted
end

local function dump(traces, aborted)
	print("====")
	print(trace_track.ToStringTraceTree(traces))
	print(trace_track.ToStringProblematicTraces(traces, aborted))
	print("====")
end

do
	local traces, aborted = test({hotloop = 56}, function()
		local x = 0

		for i = 1, 55 do
			x = x + 1
		end
	end)
	assert(trace_track.ToStringTraceTree(traces) == "")
end

do
	local traces, aborted = test({hotloop = 56}, function()
		local x = 0

		for i = 1, 56 do
			x = x + 1
		end
	end)
	assert(trace_track.ToStringTraceTree(traces) == "")
	assert(
		trace_track.ToStringProblematicTraces(traces, aborted):find("leaving loop in root trace") ~= nil
	)
end

do
	local traces, aborted = test({hotloop = 56}, function()
		local x = 0

		for i = 1, 59 do
			x = x + 1
		end
	end)
	assert(trace_track.ToStringTraceTree(traces):find("loop -") ~= nil)
	assert(trace_track.ToStringProblematicTraces(traces, aborted) == "")
end

do -- https://github.com/LuaJIT/LuaJIT/blob/v2.1/src/lj_record.c#L2701-L2704
	do -- too many ir instructions
		local traces, aborted = test({hotloop = 1, maxrecord = 1}, function()
			local x = 0

			for i = 1, 3 do
				x = x + 1
			end
		end)
		assert(trace_track.ToStringProblematicTraces(traces, aborted):find("trace too long") ~= nil)
	end

	do -- too many constants
		local traces, aborted = test({hotloop = 1, maxirconst = 1}, function()
			local x = 0

			for i = 1, 3 do
				x = x + 1
			end
		end)
		assert(trace_track.ToStringProblematicTraces(traces, aborted):find("trace too long") ~= nil)
	end

	do
		local traces, aborted = test({hotloop = 1, maxirconst = 20}, function()
			local x = 0

			for i = 1, 3 do
				x = x + 1
			end
		end)
		dump(traces, aborted)
		assert(trace_track.ToStringProblematicTraces(traces, aborted) == "")
	end
end

do
	local traces, aborted = test({hotloop = 1, maxside = 2}, function()
		local sum = 0

		for i = 1, 1000 do
			local num = math.random(1, 100)

			-- since max side is just 2, luajit can only create 2 side traces based on the main trace (the for loop)
			if num < 10 then
				sum = sum + 1
			elseif num < 20 then
				sum = sum + 2
			elseif num < 30 then
				sum = sum + 3
			elseif num < 40 then
				sum = sum + 4
			elseif num < 50 then
				sum = sum + 5
			elseif num < 60 then
				sum = sum + 6
			elseif num < 70 then
				sum = sum + 7
			elseif num < 80 then
				sum = sum + 8
			elseif num < 90 then
				sum = sum + 9
			else
				sum = sum + 10
			end
		end
	end)
	assert(trace_track.ToStringTraceTree(traces):find("interpreter") ~= nil)
end

do
	local traces, aborted = test({hotloop = 1, maxside = 20}, function()
		local sum = 0

		for i = 1, 1000 do
			local num = math.random(1, 100)

			-- since max side is 20, it can create enough side traces to cover all branches
			if num < 10 then
				sum = sum + 1
			elseif num < 20 then
				sum = sum + 2
			elseif num < 30 then
				sum = sum + 3
			elseif num < 40 then
				sum = sum + 4
			elseif num < 50 then
				sum = sum + 5
			elseif num < 60 then
				sum = sum + 6
			elseif num < 70 then
				sum = sum + 7
			elseif num < 80 then
				sum = sum + 8
			elseif num < 90 then
				sum = sum + 9
			else
				sum = sum + 10
			end
		end
	end)
	assert(trace_track.ToStringTraceTree(traces):find("interpreter") == nil)
end

do
	-- Create a metatable to force snapshots
	local traces, aborted = test({hotloop = 1, maxsnap = 5}, function()
		for j = 1, 1000 do
			local result = j

			for state = 0, 9 do
				if state == 0 then
					result = result + math.sin(state)
				elseif state == 1 then
					result = result + math.cos(state)
				elseif state == 2 then
					result = result + math.tan(state)
				elseif state == 3 then
					result = result + math.exp(state % 3)
				elseif state == 4 then
					result = result + math.log(state + 1)
				elseif state == 5 then
					result = result + math.sqrt(state + 1)
				elseif state == 6 then
					result = result + math.log(state + 1)
				elseif state == 7 then
					result = result + math.sqrt(state + 1)
				else
					result = result + #tostring(state)
				end

				collectgarbage("step", 1)
			end
		end
	end)
	dump(traces, aborted)
end