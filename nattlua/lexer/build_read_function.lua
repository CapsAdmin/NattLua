local load = loadstring or load
return function(tbl--[[#: {[number] = string}]], lower--[[#: boolean]])
	local copy = {}
	local done = {}

	for _, str in ipairs(tbl) do
		if not done[str] then
			table.insert(copy, str)
			done[str] = true
		end
	end

	table.sort(copy, function(a, b)
		return #a > #b
	end)

	local kernel = "return function(self)\n"

	for _, str in ipairs(copy) do
		local lua = "if "

		for i = 1, #str do
			local func = "self:IsByte"
			local first_arg = str:byte(i)
			local second_arg = i - 1
			lua = lua .. "(" .. func .. "(" .. table.concat({tostring(first_arg), tostring(second_arg)}, ",") .. ")"

			if lower then
				lua = lua .. " or "
				lua = lua .. func .. "(" .. table.concat({tostring(first_arg - 32), tostring(second_arg)}, ",") .. ") "
			end

			lua = lua .. ")"

			if i ~= #str then
				lua = lua .. " and "
			end
		end

		lua = lua .. " then"
		lua = lua .. " self:Advance(" .. #str .. ") return true end -- " .. str
		kernel = kernel .. lua .. "\n"
	end

	kernel = kernel .. "\nend"
	return assert(load(kernel))()
end
