--PLAIN_LUA
local memory = {}
local OS = jit and jit.os

if OS == "OSX" then
	local ffi = require("ffi")
	ffi.cdef[[
        unsigned int mach_task_self();
        int task_info(unsigned int target_task, int flavor, void* task_info_out, unsigned int* task_info_outCnt);
    ]]
	local task_info = ffi.typeof([[ struct {
            uint64_t virtual_size;
            uint64_t resident_size;
            uint64_t resident_size_max;
            uint64_t user_time;
            uint64_t system_time;
            int policy;
            int suspend_count;
        }
    ]])
	local TASK_BASIC_INFO = 20
	local info = task_info()
	local count = ffi.new("int[1]", ffi.sizeof(info) / 4)

	function memory.get_usage_kb()
		local task = ffi.C.mach_task_self()
		local result = ffi.C.task_info(task, TASK_BASIC_INFO, info, count)

		if result == 0 then return tonumber(info.resident_size) / 1024 end

		return nil, "task_info failed with error: " .. result
	end
else
	function memory.get_usage_kb()
		return collectgarbage("count")
	end

	return memory
end

return memory
