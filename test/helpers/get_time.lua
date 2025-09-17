local tonumber = _G.tonumber
local has_ffi, ffi = pcall(require, "ffi")

if not has_ffi then return os.clock end

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
