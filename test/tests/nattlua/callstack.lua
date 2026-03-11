local callstack = require("nattlua.other.callstack")

test("callstack traceback level stripping", function()
	local function level2()
		return callstack.traceback(nil, 2)
	end

	local function level1()
		return level2()
	end

	local trace = level1()
	-- The traceback should have skipped:
	-- 1. callstack.traceback
	-- 2. level2
	-- 3. level1
	-- So the first line of the trace (after "stack traceback:\n") should be this test function.
	-- We check if 'level1' or 'level2' or 'callstack.lua' are in the first few lines of the actual output
	-- after the header.
	local lines = {}

	for line in trace:gmatch("(.-)\n") do
		table.insert(lines, line)
	end

	equal(lines[1], "stack traceback:")
	-- Check that the first frame is NOT level2, level1, or callstack.lua
	local first_frame = lines[2] or ""

	if
		first_frame:find("callstack.lua") or
		first_frame:find("level1") or
		first_frame:find("level2")
	then
		error("traceback did not strip levels correctly:\n" .. trace)
	end
end)

test("callstack traceback negative index reverses", function()
	local function level2()
		return callstack.traceback(nil, -2)
	end

	local function level1()
		return level2()
	end

	local trace = level1()
	local lines = {}

	for line in trace:gmatch("(.-)\n") do
		table.insert(lines, line)
	end

	equal(lines[1], "stack traceback:")
	local last_frame = lines[#lines]

	if
		last_frame:find("callstack.lua") or
		last_frame:find("level1") or
		last_frame:find("level2")
	then
		error("traceback did not reverse correctly:\n" .. trace)
	end
end)
