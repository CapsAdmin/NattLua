--ANALYZE
local function tostringx(obj--[[#: any]])--[[#: string]]
	if type(obj) == "function" then
		local info = debug.getinfo(obj)

		if info.source == "=[C]" then
			return "function() end -- C function"
		else
			local params = {}

			for i = 1, math.huge do
				local key = debug.getlocal(obj, i)

				if key then table.insert(params, key) else break end
			end

			return "function(" .. table.concat(params, ", ") .. ") end" -- " .. info.source .. ":" .. info.linedefined
		end
	end

	local ok, str = pcall(tostring, obj)

	if not ok then return "tostring error: " .. str end

	return str
end

local function file_read(path--[[#: string]])--[[#: string]]
	local f = assert(io.open(path, "r"))
	local str = assert(f:read("*all"), "file is empty")
	f:close()
	return str
end

local function line_from_info(info--[[#: debug_getinfo]], line--[[#: number]])--[[#: string]]
	if info.source:sub(1, 1) == "@" then
		local lua = file_read(info.source:sub(2))
		local i = 1

		for str in (lua .. "\n"):gmatch("(.-)\n") do
			if line == i then return str end

			i = i + 1
		end
	end
end

local function func_line_from_info(
	info--[[#: debug_getinfo]],
	line_override--[[#: number]],
	fallback_info--[[#: string]],
	nocomment--[[#: boolean]]
)
	if info.source then
		local line = line_from_info(info, line_override or info.linedefined)

		if line and line:find("%b()") then
			line = line:gsub("^%s*", ""):reverse():gsub("^%s*", ""):reverse() -- trim
			return line .. (
					nocomment and
					"" or
					" -- inlined function " .. (
						info.name or
						fallback_info or
						"__UNKNOWN__"
					)
				)
		end
	end

	if info.source == "=[C]" then
		return "function " .. (info.name or fallback_info or "__UNKNOWN__") .. "(=[C])"
	end

	local str = "function " .. (info.name or fallback_info or "__UNKNOWN__")
	str = str .. "("
	local arg_line = {}

	if info.isvararg then
		table.insert(arg_line, "...")
	else
		for i = 1, info.nparams do
			local key, val = debug.getlocal(info.func, i)

			if not key then break end

			if key == "(*temporary)" then
				table.insert(arg_line, tostringx(val))
			elseif key:sub(1, 1) ~= "(" then
				table.insert(arg_line, key)
			end
		end
	end

	str = str .. table.concat(arg_line, ", ")
	str = str .. ")"
	return str
end

return function(offset--[[#: number]], check_level--[[#: number]])--[[#: string]]
	offset = offset or 0
	local str = ""
	local max_level = 0
	local min_level = offset

	for level = min_level, math.huge do
		if not debug.getinfo(level) then break end

		max_level = level
	end

	local extra_indent = 3
	local for_loop
	local for_gen

	for level = max_level, min_level, -1 do
		local info = debug.getinfo(level)

		if not info then break end

		if check_level and check_level(info, level) ~= nil then break end

		local normalized_level = -level + max_level
		local t = (" "):rep(normalized_level + extra_indent)

		if level == max_level then
			str = str .. normalized_level .. ": "
			str = str .. func_line_from_info(info) .. "\n"
		elseif level ~= min_level then
			if info.source ~= "=[C]" then
				str = str .. "\n"
				local info = debug.getinfo(level + 1) or info
				str = str .. t .. func_line_from_info(info, info.currentline, nil, true) .. " >> \n"
			end

			str = str .. normalized_level .. ": "
			t = t:sub(4)
			str = str .. t .. func_line_from_info(info)
			str = str .. "\n"
			extra_indent = extra_indent + 1
		end

		local t = (" "):rep(normalized_level + extra_indent)

		for i = 1, math.huge do
			local key, val = debug.getlocal(level, i)

			if not key then break end

			if key == "(for generator)" then
				for_gen = ""
			elseif key == "(for state)" then

			elseif key == "(for control)" then

			elseif key == "(for index)" then
				for_loop = ""
			elseif key == "(for limit)" then
				for_loop = for_loop .. val .. ", "
			elseif key == "(for step)" then
				for_loop = for_loop .. val .. " do"
			elseif key ~= "(*temporary)" then
				if for_loop then
					str = str .. t .. "for " .. key .. " = " .. val .. ", " .. for_loop .. "\n"
					extra_indent = extra_indent + 1
					t = (" "):rep(-level + max_level + extra_indent)
					for_loop = nil
				else
					if for_gen then
						if for_gen == "" then
							for_gen = "for " .. key .. " = " .. tostringx(val) .. ", "
						else
							for_gen = for_gen .. key .. " = " .. tostringx(val) .. " in ??? do"
							str = str .. t .. for_gen .. "\n"
							extra_indent = extra_indent + 1
							t = (" "):rep(normalized_level + extra_indent)
							for_gen = nil
						end
					else
						str = str .. t .. key .. " = " .. tostringx(val) .. "\n"
					end
				end
			end
		end

		if level == min_level then
			str = str .. ">>" .. t:sub(3) .. func_line_from_info(info, info.currentline) .. " <<\n"
		end
	end

	return str
end
