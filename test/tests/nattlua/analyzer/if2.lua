--PLAIN_LUA
local function test_boolean_logic(values, ...)
	local conditions = {...}
	local var_names = {}

	for var_name, _ in pairs(values) do
		table.insert(var_names, var_name)
	end

	table.sort(var_names)

	local function generate_combinations(values, var_names, index, current_combo, all_combos)
		if index > #var_names then
			table.insert(all_combos, {unpack(current_combo)})
			return
		end

		local var_name = var_names[index]

		for _, value in ipairs(values[var_name]) do
			current_combo[index] = {var_name, value}
			generate_combinations(values, var_names, index + 1, current_combo, all_combos)
		end
	end

	local all_combinations = {}
	generate_combinations(values, var_names, 1, {}, all_combinations)

	local function evaluate_condition(combination, condition)
		local env = {}

		for _, var_val in ipairs(combination) do
			env[var_val[1]] = var_val[2]
		end

		local condition_code = "return " .. condition
		local condition_func, err = load(condition_code, "condition", "t", env)

		if not condition_func then
			error("Failed to compile condition '" .. condition .. "': " .. err)
		end

		local success, result = pcall(condition_func)

		if not success then
			error("Failed to evaluate condition '" .. condition .. "': " .. result)
		end

		return result
	end

	local branch_results = {}

	for i, condition in ipairs(conditions) do
		branch_results[i] = {
			type = i == 1 and "if" or "elseif",
			condition = condition,
			combinations = {},
		}
	end

	branch_results[#conditions + 1] = {type = "else", condition = nil, combinations = {}}

	for _, combination in ipairs(all_combinations) do
		local branch_index = nil

		for i, condition in ipairs(conditions) do
			if evaluate_condition(combination, condition) then
				branch_index = i

				break
			end
		end

		if not branch_index then branch_index = #conditions + 1 end

		table.insert(branch_results[branch_index].combinations, combination)
	end

	local function format_combinations_for_branch(combinations, var_names)
		local var_values = {}

		for _, var_name in ipairs(var_names) do
			var_values[var_name] = {}
		end

		for _, combination in ipairs(combinations) do
			for _, var_val in ipairs(combination) do
				local var_name, value = var_val[1], var_val[2]
				local found = false

				for _, existing_val in ipairs(var_values[var_name]) do
					if existing_val == value then
						found = true

						break
					end
				end

				if not found then table.insert(var_values[var_name], value) end
			end
		end

		for var_name, vals in pairs(var_values) do
			table.sort(vals, function(a, b)
				if type(a) == "number" and type(b) == "number" then return a > b end

				if type(a) == "boolean" and type(b) == "boolean" then
					return (a and 1 or 0) > (b and 1 or 0)
				end

				return tostring(a) > tostring(b)
			end)
		end

		return var_values
	end

	local output_lines = {}

	for _, name in ipairs(var_names) do
		local str = {}

		for _, val in ipairs(values[name]) do
			table.insert(str, tostring(val))
		end

		table.insert(output_lines, "local " .. name .. " = _ as " .. table.concat(str, " | "))
	end

	for i, branch_result in ipairs(branch_results) do
		if branch_result.type == "if" then
			table.insert(output_lines, "if " .. branch_result.condition .. " then")
		elseif branch_result.type == "elseif" then
			table.insert(output_lines, "elseif " .. branch_result.condition .. " then")
		else
			table.insert(output_lines, "else")
		end

		if #branch_result.combinations > 0 then
			local var_values = format_combinations_for_branch(branch_result.combinations, var_names)

			for _, var_name in ipairs(var_names) do
				if var_values[var_name] and #var_values[var_name] > 0 then
					local str = {}

					for i, v in ipairs(var_values[var_name]) do
						str[i] = tostring(v)
					end

					table.insert(
						output_lines,
						"    attest.equal(" .. var_name .. ", _ as " .. table.concat(str, " | ") .. ")"
					)
				end
			end
		else
			table.insert(output_lines, "    error(\"never\")")
		end
	end

	table.insert(output_lines, "end")
	return table.concat(output_lines, "\n")
end

analyze(test_boolean_logic({a = {true, false}}, "a"))
analyze(test_boolean_logic({a = {true, false}}, "not a"))--
--analyze(test_boolean_logic({a = {true, false}}, "not not a"))
--analyze(test_boolean_logic({a = {1, 2, 3}, b = {true, false}}, "b and a == 1"))
