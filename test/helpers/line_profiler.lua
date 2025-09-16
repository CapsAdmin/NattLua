--[[HOTRELOAD 
    run_lua("test/performance/lexer.lua")
]]
local ffi = require("ffi")
local preprocess = require("test.helpers.preprocess")
local line_hook = require("test.helpers.line_hook")
local formating = require("nattlua.other.formating")
local colors = require("nattlua.cli.colors")
local line_profiler = {}
local get_time_raw, get_time_seconds

if ffi.os == "OSX" then
	ffi.cdef([[
		uint64_t clock_gettime_nsec_np(int clock_id);
	]])
	local C = ffi.C
	local CLOCK_UPTIME_RAW_APPROX = 9
	local start_time = C.clock_gettime_nsec_np(CLOCK_UPTIME_RAW_APPROX)
	get_time_raw = function()
		return C.clock_gettime_nsec_np(CLOCK_UPTIME_RAW_APPROX)
	end
	get_time_seconds = function(raw_time)
		return tonumber(raw_time) / 1000000000.0
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
	get_time_raw = function()
		local time = ffi.new("int64_t[1]")
		ffi.C.QueryPerformanceCounter(time)
		return time[0]
	end
	get_time_seconds = function(raw_time)
		return tonumber(raw_time) / freq
	end
else
	ffi.cdef([[
		struct timespec { long tv_sec; long tv_nsec; };
		int clock_gettime(int clock_id, struct timespec *tp);
	]])
	local CLOCK_MONOTONIC = 1
	local ts = ffi.new("struct timespec")
	get_time_raw = function()
		ffi.C.clock_gettime(CLOCK_MONOTONIC, ts)
		return ts.tv_sec * 1000000000ULL + ts.tv_nsec
	end
	get_time_seconds = function(raw_time)
		return tonumber(raw_time) / 1000000000.0
	end
end

-- Define the event structure
ffi.cdef(
	[[
typedef struct {
    uint8_t type;        // 0 = open, 1 = close
    uint16_t path_id;    // Index into path lookup table
    uint32_t start_pos;  // Start position from start_stop
    uint32_t end_pos;    // End position from start_stop
    $ time;              // Timestamp (raw time type)
} profile_event_t;

void* malloc(size_t size);
void* realloc(void* ptr, size_t size);
void free(void* ptr);
]],
	ffi.typeof(get_time_raw())
)

-- this must be called before loading modules
function line_profiler.Start(whitelist)
	whitelist = whitelist or {"^nattlua/"}

	local function matches_whitelist(path)
		for _, pattern in ipairs(whitelist) do
			if path:find(pattern) then return true end
		end

		return false
	end

	-- Event storage
	local events_capacity = 100000ULL -- Start with 100k events
	local event_size = ffi.sizeof("profile_event_t")
	local events_ptr = ffi.C.malloc(events_capacity * event_size)

	if events_ptr == nil then
		error("Failed to allocate memory for events array")
	end

	local events = ffi.cast("profile_event_t*", events_ptr)
	local event_count = 0
	-- Path lookup tables
	local path_to_id = {}
	local id_to_path = {}
	local next_path_id = 0

	local function get_path_id(path)
		local id = path_to_id[path]

		if not id then
			id = next_path_id
			path_to_id[path] = id
			id_to_path[id] = path
			next_path_id = next_path_id + 1
		end

		return id
	end

	local function grow_events_array()
		local new_capacity = events_capacity * 2ULL
		local new_events_ptr = ffi.C.realloc(events_ptr, new_capacity * event_size)

		if new_events_ptr == nil then
			error("Failed to reallocate memory for events array")
		end

		events_ptr = new_events_ptr
		events = ffi.cast("profile_event_t*", events_ptr)
		events_capacity = new_capacity
	end

	local start_time = get_time_raw()

	function _G.LINE_OPEN(path, start, stop)
		if event_count >= events_capacity then grow_events_array() end

		local event = events[event_count]
		event.type = 0 -- open
		event.path_id = get_path_id(path)
		event.start_pos = start
		event.end_pos = stop
		event.time = get_time_raw()
		event_count = event_count + 1
	end

	function _G.LINE_CLOSE(path, start, stop)
		if event_count >= events_capacity then grow_events_array() end

		local event = events[event_count]
		event.type = 1 -- close
		event.path_id = get_path_id(path)
		event.start_pos = start
		event.end_pos = stop
		event.time = get_time_raw()
		event_count = event_count + 1
	end

	function preprocess.Preprocess(code, name, path, from)
		if from == "package" then
			if path and matches_whitelist(path) then
				io.write("profiling " .. path .. "\n")
				local code = line_hook.Preprocess(code, name, path, from)
				return code
			end
		end

		return code
	end

	local dispose = preprocess.Init(
		(
			function()
				local tbl = {}

				for k, v in pairs(package.loaded) do
					if k:find("preprocess") or k:find("line_hook") then

					-- skip these
					else
						if k:find("nattlua") or k:find("test%.") then
							table.insert(tbl, k)
							io.write("unloading " .. k .. "\n")
						end
					end
				end

				return tbl
			end
		)()
	)
	return function()
		dispose()
		_G.LINE_OPEN = nil
		_G.LINE_CLOSE = nil
		local end_time = get_time_raw()
		local total_profiling_time = get_time_seconds(end_time - start_time)
		-- Process events to calculate times (keep everything in raw time units)
		local lines = {} -- key -> {path, start_pos, end_pos, inclusive_time_raw, exclusive_time, count}
		local call_stack = {}

		for i = 0, event_count - 1 do
			local event = events[i]
			local path = id_to_path[event.path_id]
			local key = path .. "|" .. event.start_pos .. "_" .. event.end_pos

			if event.type == 0 then -- open
				-- Push onto stack
				table.insert(
					call_stack,
					{
						path = path,
						start_pos = event.start_pos,
						end_pos = event.end_pos,
						start_time = event.time, -- raw time
						children_time = 0, -- raw time
					}
				)

				-- Initialize line data if needed
				if not lines[key] then
					lines[key] = {
						path = path,
						start_pos = event.start_pos,
						end_pos = event.end_pos,
						inclusive_time_raw = 0, -- raw time
						exclusive_time_raw = 0, -- raw time
						count = 0,
					}
				end

				lines[key].count = lines[key].count + 1
			elseif event.type == 1 then -- close
				-- Find matching open on stack
				local stack_pos = #call_stack
				local found = false

				while stack_pos > 0 do
					local stack_entry = call_stack[stack_pos]

					if
						stack_entry.path == path and
						stack_entry.start_pos == event.start_pos and
						stack_entry.end_pos == event.end_pos
					then
						found = true

						break
					end

					stack_pos = stack_pos - 1
				end

				if found then
					local stack_entry = table.remove(call_stack, stack_pos)
					local elapsed = event.time - stack_entry.start_time -- raw time difference
					local exclusive = elapsed - stack_entry.children_time -- raw time difference
					if lines[key] then
						lines[key].inclusive_time_raw = lines[key].inclusive_time_raw + elapsed
						lines[key].exclusive_time_raw = lines[key].exclusive_time_raw + exclusive
					end

					-- Add this time to parent's children_time (raw time)
					if stack_pos > 1 then
						call_stack[stack_pos - 1].children_time = call_stack[stack_pos - 1].children_time + elapsed
					end
				end
			end
		end

		-- Handle any unclosed entries
		local unclosed_count = #call_stack
		-- Convert to the expected format and sort
		local sorted_files = {}
		local files_map = {}

		for key, line_data in pairs(lines) do
			local path = line_data.path
			files_map[path] = files_map[path] or {}
			table.insert(files_map[path], line_data)
		end

		for path, lines in pairs(files_map) do
			local f = assert(io.open(path, "r"))
			local lua = f:read("*a")
			f:close()
			local total_inclusive = 0 -- raw time
			local total_exclusive = 0 -- raw time
			for _, line in ipairs(lines) do
				local info = formating.SubPosToLineCharCached(lua, line.start_pos, line.end_pos)
				line.path_line = line.path .. ":" .. info.line_start .. ":" .. info.character_start
				total_inclusive = total_inclusive + line.inclusive_time_raw
				total_exclusive = total_exclusive + line.exclusive_time_raw
			end

			-- Sort by exclusive time
			table.sort(lines, function(a, b)
				return a.exclusive_time_raw < b.exclusive_time_raw
			end)

			table.insert(
				sorted_files,
				{
					path = path,
					lines = lines,
					total_inclusive = total_inclusive, -- raw time
					total_exclusive = total_exclusive, -- raw time
				}
			)
		end

		table.sort(sorted_files, function(a, b)
			return a.total_exclusive < b.total_exclusive
		end)

		-- Generate report
		local str = {}

		-- Convert raw time to formatted string
		local function format_time(raw_time)
			local seconds = get_time_seconds(raw_time)

			if seconds > 1 then
				return string.format("%.2fs", seconds)
			elseif seconds > 0.01 then
				return string.format("%.1fms", seconds * 1000)
			end

			return string.format("%.0fus", seconds * 1000000)
		end

		local function format_colored(raw_time)
			local seconds = get_time_seconds(raw_time)
			local time_str = format_time(raw_time)

			if seconds > 0.1 then
				return colors.red(time_str)
			elseif seconds > 0.01 then
				return colors.yellow(time_str)
			end

			return colors.green(time_str)
		end

		local function pad_right(str, len)
			while #str < len do
				str = str .. " "
			end

			return str
		end

		-- Calculate total exclusive time across all files (raw time)
		local total_exclusive_all = 0

		for _, file in ipairs(sorted_files) do
			total_exclusive_all = total_exclusive_all + file.total_exclusive
		end

		table.insert(str, "=== PROFILING SUMMARY ===")
		table.insert(str, "Wall clock time: " .. string.format("%.3fs", total_profiling_time))
		table.insert(str, "Total exclusive time: " .. format_time(total_exclusive_all))
		table.insert(str, "Processed events: " .. event_count)
		table.insert(str, "Memory used: " .. (event_count * ffi.sizeof("profile_event_t")) .. " bytes")
		table.insert(str, "Unclosed entries: " .. unclosed_count)
		table.insert(str, "")

		for _, file in ipairs(sorted_files) do
			local line_length = 0

			for _, line in ipairs(file.lines) do
				line_length = math.max(line_length, #line.path_line)
			end

			table.insert(
				str,
				pad_right(file.path, line_length + 1) .. " - exclusive: " .. format_colored(file.total_exclusive) .. " (inclusive: " .. format_colored(file.total_inclusive) .. ")"
			)

			for _, line in ipairs(file.lines) do
				-- Only show lines with meaningful time (convert to seconds for threshold)
				if get_time_seconds(line.exclusive_time_raw) > 0.0001 then
					local percent = total_exclusive_all > 0 and
						(
							tonumber(line.exclusive_time_raw) / tonumber(total_exclusive_all)
						) * 100 or
						0
					table.insert(
						str,
						" " .. pad_right(line.path_line, line_length) .. " - " .. format_colored(line.exclusive_time_raw) .. string.format(" (%.1f%%, count: %d)", percent, line.count)
					)
				end
			end

			table.insert(str, "")
		end

		-- Free the malloc'd events array
		ffi.C.free(events_ptr)
		return table.concat(str, "\n")
	end
end

return line_profiler
