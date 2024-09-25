--ANALYZE
local jit = require("jit")
local jit_profiler = require("jit.profile")
local jit_vmdef = require("jit.vmdef")
local jit_util = require("jit.util")
local dumpstack = jit_profiler.dumpstack
local profiler = {}
--[[#local type VMState = "I" | "G" | "N" | "J" | "C"]]
local raw_samples--[[#: List<|{
	stack = string,
	sample_count = number,
	vm_state = VMState,
}|>]]

local function starts_with(str--[[#: string]], what--[[#: string]])
	return str:sub(1, #what) == what
end

function profiler.Start(config--[[#: {
	depth = number | nil,
	sampling_rate = number | nil,
} | nil]])
	config = config or {}
	config.depth = config.depth or 1
	config.sampling_rate = config.sampling_rate or 10
	raw_samples = {}
	local i = 1

	jit_profiler.start("li" .. config.sampling_rate, function(thread, sample_count--[[#: number]], vmstate--[[#: VMState]])
		raw_samples[i] = {
			stack = dumpstack(thread, "pl\n", config.depth),
			sample_count = sample_count,
			vm_state = vmstate,
		}
		i = i + 1
	end)
end

function profiler.Stop(config--[[#: {sample_threshold = number | nil} | nil]])
	config = config or {}
	config.sample_threshold = config.sample_threshold or 50
	jit_profiler.stop()
	local processed_samples--[[#: Map<|
		string,
		{
			sample_count = number,
			vm_states = Map<|VMState, number|>,
			children = Map<|
				number,
				{
					sample_count = number,
					vm_states = Map<|VMState, number|>,
				}
			|>,
		}
	|>]] = {}

	for _, sample in ipairs(raw_samples) do
		local stack = {}

		for line in sample.stack:gmatch("(.-)\n") do
			if
				starts_with(line, "[builtin") or
				starts_with(line, "(command line)") or
				starts_with(line, "@0x")
			then

			-- these can safely be ignored
			else
				local path, line_number = line:match("(.+):(.+)")

				if not path or not line_number then error("uh oh") end

				local line_number = assert(tonumber(line_number))

				do
					if not processed_samples[path] then
						processed_samples[path] = {lines = {}}
					end
					if not processed_samples[path].lines[line_number] then
						processed_samples[path].lines[line_number] = {}
					end

					local vm_states = processed_samples[path].lines[line_number]

					vm_states[sample.vm_state] = (vm_states[sample.vm_state] or 0) + sample.sample_count					
				end
			end
		end
	end

	local function get_samples(vm_states)
		local count = 0
		for k,v in pairs(vm_states) do
			count = count + v
		end
		return count
	end

	local sorted_samples = {}

	do

		for path, data in pairs(processed_samples) do
			local new_lines = {}
			local other_lines = {}
			for line_number, vm_states in pairs(data.lines) do
				if get_samples(vm_states) < config.sample_threshold then
					other_lines[line_number] = vm_states
				else
					new_lines[line_number] = vm_states
				end
			end
			data.lines = new_lines
			data.other_lines = other_lines
		end
		for path, data in pairs(processed_samples) do
			local lines = {}
			local total_sample_count = 0
			local total_vm_states = {}

			do

				for line_number, vm_states in pairs(data.lines) do
					local samples = get_samples(vm_states)
					table.insert(
						lines,
						{
							path = path .. ":" .. line_number,
							sample_count = samples,
							vm_states = vm_states,
						}
					)

					for k,v in pairs(vm_states) do
						total_vm_states[k] = (total_vm_states[k] or 0) + v
						total_sample_count = total_sample_count + v
					end
				end
			end

			do
				local path = "other"
				local sample_count = 0
				local new_vm_states = {}

				for line_number, vm_states in pairs(data.other_lines) do
					for k,v in pairs(vm_states) do
						new_vm_states[k] = (new_vm_states[k] or 0) + v
						sample_count = sample_count + v
					end
				end

				table.insert(
					lines,
					{
						path = "other",
						sample_count = sample_count,
						vm_states = new_vm_states,
					}
				)
			end

			table.sort(lines, function(a, b)
				return a.sample_count < b.sample_count
			end)

			table.insert(
				sorted_samples,
				{
					path = path,
					vm_states = total_vm_states,
					lines = lines,
					sample_count = total_sample_count,
				}
			)
		end

		table.sort(sorted_samples, function(a, b)
			return a.sample_count < b.sample_count
		end)
	end

	local vm_state_name_order = {"I", "G", "N", "J", "C"}

	local function stacked_barchart(vm_states--[[#: Map<|VMState, number|>]], sample_count--[[#: number]])
		local len = 20
		local states = {}
		local sum = 0

		for _, v in pairs(vm_state_name_order) do
			states[v] = math.floor(((vm_states[v] or 0) / sample_count) * len)
			sum = sum + states[v]
		end

		local diff = len - sum

		for i = 1, diff do
			local max_val = 0
			local max_index = nil

			for k, v in pairs(states) do
				if v >= max_val then
					max_val = v
					max_index = k
				end
			end

			if max_index then
				states[max_index] = states[max_index] + 1
			end
		end

		local result = ""

		for _, name in ipairs(vm_state_name_order) do
			result = result .. string.rep(name, states[name])
		end

		return result
	end

	local out = {}

	for _, data in ipairs(sorted_samples) do
		local str = {}

		for _, data in ipairs(data.lines) do
			table.insert(
				str,
				stacked_barchart(data.vm_states, data.sample_count) .. "\t" .. data.sample_count .. "\t" .. data.path .. "\n"
			)
		end

		if str[1] then
			table.insert(
				str,
				stacked_barchart(data.vm_states, data.sample_count) .. "\t" .. data.sample_count .. "\t" .. " < total" .. "\n\n"
			)
		end

		if str[1] then table.insert(out, table.concat(str)) end
	end

	return table.concat(out)
end

return profiler