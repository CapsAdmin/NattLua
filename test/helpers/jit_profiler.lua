--ANALYZE
local ipairs = _G.ipairs
local table_concat = _G.table.concat
local table_insert = _G.table.insert
local profiler = {}
-- Section tracking state
local profiler_active = false
local section_stack = {}
local current_section_path = ""
--[[#local type VMState = "I" | "G" | "N" | "J" | "C"]]
--[[#local type Config = {
	mode = "function" | "line" | nil,
	depth = number | nil,
	sampling_rate = 1 .. inf | nil,
	threshold = number | nil,
}]]

function profiler.StartSection(name--[[#: string]])
	if not profiler_active then return end

	table_insert(section_stack, name)
	current_section_path = table_concat(section_stack, " > ")
end

function profiler.StopSection()
	if not profiler_active then return end

	if #section_stack > 0 then
		section_stack[#section_stack] = nil
		current_section_path = table_concat(section_stack, " > ")
	end
end

local function starts_with(str--[[#: string]], what--[[#: string]])
	return str:sub(1, #what) == what
end

local function process_samples(
	config--[[#: Required<|Config|>]],
	raw_samples--[[#: List<|
		{
			stack = string,
			sample_count = number,
			vm_state = VMState,
			section_path = string,
		}
	|>]]
)
	local processed_samples = {}
	local section_samples = {}

	for _, sample in ipairs(raw_samples) do
		local section_key = sample.section_path == "" and "(no section)" or sample.section_path

		if not section_samples[section_key] then
			section_samples[section_key] = {}
		end

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

				if path:sub(1, 2) == "./" then path = path:sub(3) end

				local line_number = assert(tonumber(line_number))

				do
					if not section_samples[section_key][path] then
						section_samples[section_key][path] = {lines = {}}
					end

					if not section_samples[section_key][path].lines[line_number] then
						section_samples[section_key][path].lines[line_number] = {}
					end

					local vm_states = section_samples[section_key][path].lines[line_number]
					vm_states[sample.vm_state] = (vm_states[sample.vm_state] or 0) + sample.sample_count
				end
			end
		end
	end

	-- Convert section_samples to the expected format
	for section_key, section_data in pairs(section_samples) do
		processed_samples[section_key] = section_data
	end

	local function get_samples(vm_states)
		local count = 0

		for k, v in pairs(vm_states) do
			count = count + v
		end

		return count
	end

	local sorted_samples = {}

	do
		for section_key, section_data in pairs(processed_samples) do
			for path, data in pairs(section_data) do
				local new_lines = {}
				local other_lines = {}

				for line_number, vm_states in pairs(data.lines) do
					if get_samples(vm_states) < config.threshold then
						other_lines[line_number] = vm_states
					else
						new_lines[line_number] = vm_states
					end
				end

				data.lines = new_lines
				data.other_lines = other_lines
			end
		end

		for section_key, section_data in pairs(processed_samples) do
			local section_samples = {}

			for path, data in pairs(section_data) do
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

						for k, v in pairs(vm_states) do
							total_vm_states[k] = (total_vm_states[k] or 0) + v
							total_sample_count = total_sample_count + v
						end
					end
				end

				do
					local path = "other samples < " .. config.threshold
					local sample_count = 0
					local new_vm_states = {}

					for line_number, vm_states in pairs(data.other_lines) do
						for k, v in pairs(vm_states) do
							new_vm_states[k] = (new_vm_states[k] or 0) + v
							sample_count = sample_count + v
							total_vm_states[k] = (total_vm_states[k] or 0) + v
							total_sample_count = total_sample_count + v
						end
					end

					table.insert(
						lines,
						{
							other = true,
							path = path,
							sample_count = sample_count,
							vm_states = new_vm_states,
						}
					)
				end

				table.sort(lines, function(a, b)
					return a.sample_count < b.sample_count
				end)

				table.insert(
					section_samples,
					{
						path = path,
						vm_states = total_vm_states,
						lines = lines,
						sample_count = total_sample_count,
					}
				)
			end

			table.sort(section_samples, function(a, b)
				return a.sample_count < b.sample_count
			end)

			table.insert(
				sorted_samples,
				{
					section = section_key,
					samples = section_samples,
				}
			)
		end

		table.sort(sorted_samples, function(a, b)
			local a_total = 0
			local b_total = 0

			for _, sample in ipairs(a.samples) do
				a_total = a_total + sample.sample_count
			end

			for _, sample in ipairs(b.samples) do
				b_total = b_total + sample.sample_count
			end

			return a_total < b_total
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

			if max_index then states[max_index] = states[max_index] + 1 end
		end

		local result = ""

		for _, name in ipairs(vm_state_name_order) do
			result = result .. string.rep(name, states[name])
		end

		return result
	end

	local out = {}

	for _, section_data in ipairs(sorted_samples) do
		-- Add section header if it's not the default section
		if section_data.section ~= "(no section)" then
			table_insert(out, "\n" .. section_data.section .. ":\n")
		end

		for _, data in ipairs(section_data.samples) do
			local str = {}
			local other

			for _, data in ipairs(assert(data.lines)) do
				if data.other then
					other = data
				else
					table_insert(
						str,
						stacked_barchart(data.vm_states, data.sample_count) .. "\t" .. data.sample_count .. "\t" .. data.path .. "\n"
					)
				end
			end

			if str[1] then
				table_insert(
					str,
					stacked_barchart(data.vm_states, data.sample_count) .. "\t" .. data.sample_count .. "\t" .. "total + " .. (
							other and
							other.sample_count or
							0
						) .. "\n\n"
				)
			end

			if str[1] then table_insert(out, table_concat(str)) end
		end
	end

	table_insert(out, 1, "\nprofiler statistics:\n")
	table_insert(
		out,
		2,
		"I = interpreter, G = garbage collection, J = busy tracing, N = native / tracing completed:\n"
	)
	return table_concat(out)
end

function profiler.Start(config--[[#: Config | nil]])
	config = config or {}
	config.mode = config.mode or "line"
	config.depth = config.depth or 10
	config.sampling_rate = config.sampling_rate or 1
	config.threshold = config.threshold or 50
	local ok, func = pcall(require, "jit.profile")

	if not ok then return nil, func end

	-- Reset section state
	profiler_active = true
	section_stack = {}
	current_section_path = ""
	local jit_profiler = func--[[# as any]]
	local dumpstack = jit_profiler.dumpstack--[[# as function=(string, number)>(string) | function=(any, string, number)>(string)]]
	local raw_samples--[[#: List<|
		{
			stack = string,
			sample_count = number,
			vm_state = VMState,
			section_path = string,
		}
	|>]] = {}
	local i = 1

	jit_profiler.start((config.mode == "line" and "l" or "f") .. "i" .. config.sampling_rate, function(thread, sample_count--[[#: number]], vmstate--[[#: VMState]])
		raw_samples[i] = {
			stack = dumpstack(thread, "pl\n", config.depth),
			sample_count = sample_count,
			vm_state = vmstate,
			section_path = current_section_path,
		}
		i = i + 1
	end)

	return function()
		jit_profiler.stop()
		profiler_active = false
		return process_samples(config, raw_samples)
	end
end

return profiler
