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
					local parent = processed_samples[path] or {children = {}, sample_count = 0, vm_states = {}}
					parent.sample_count = parent.sample_count + sample.sample_count
					parent.vm_states[sample.vm_state] = (parent.vm_states[sample.vm_state] or 0) + 1
					processed_samples[path] = parent
				end

				do
					local child = processed_samples[path].children[line_number] or
						{sample_count = 0, vm_states = {}}
					child.sample_count = child.sample_count + sample.sample_count
					child.vm_states[sample.vm_state] = (child.vm_states[sample.vm_state] or 0) + 1
					processed_samples[path].children[line_number] = child
				end
			end
		end
	end

	local sorted_samples = {}

	do
		for path, data in pairs(processed_samples) do
			local lines = {}

			for line_number, data in pairs(data.children) do
				table.insert(
					lines,
					{
						path = path .. ":" .. line_number,
						sample_count = data.sample_count,
						vm_states = data.vm_states,
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
					vm_states = data.vm_states,
					lines = lines,
					sample_count = data.sample_count,
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

			states[max_index] = states[max_index] + 1
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

		if data.sample_count > config.sample_threshold then
			for _, data in ipairs(data.lines) do
				if data.sample_count > config.sample_threshold then
					table.insert(
						str,
						stacked_barchart(data.vm_states, data.sample_count) .. "\t" .. data.sample_count .. "\t" .. data.path .. "\n"
					)
				end
			end

			if str[1] then
				table.insert(
					str,
					stacked_barchart(data.vm_states, data.sample_count) .. "\t" .. data.sample_count .. "\t" .. " < total" .. "\n\n"
				)
			end
		end

		if str[1] then table.insert(out, table.concat(str)) end
	end

	return table.concat(out)
end

return profiler