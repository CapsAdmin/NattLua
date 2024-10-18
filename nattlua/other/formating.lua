--ANALYZE
local math = _G.math
local table = _G.table
local type = _G.type
local tonumber = _G.tonumber
local tostring = _G.tostring
local error = _G.error
local ipairs = _G.ipairs
local stringx = require("nattlua.other.string")
local mathx = require("nattlua.other.math")
local formating = {}

function formating.QuoteToken(str--[[#: string]])--[[#: string]]
	return "❲" .. str .. "❳"
end

function formating.QuoteTokens(var--[[#: List<|string|>]])--[[#: string]]
	local str = ""

	for i, v in ipairs(var) do
		str = str .. formating.QuoteToken(v)

		if i == #var - 1 then
			str = str .. " or "
		elseif i ~= #var then
			str = str .. ", "
		end
	end

	return str
end

function formating.LinePositionToSubPosition(code--[[#: string]], line--[[#: number]], character--[[#: number]])--[[#: number]]
	line = math.max(line, 1)
	character = math.max(character, 1)
	local line_pos = 1

	for i = 1, #code do
		local c = code:sub(i, i)

		if line_pos == line then
			local char_pos = 1

			for i = i, i + character do
				local c = code:sub(i, i)

				if c == "\n" or c == "" then return i - 1 end

				if char_pos == character then return i end

				char_pos = char_pos + 1
			end

			return i
		end

		if c == "\n" or c == "" then line_pos = line_pos + 1 end
	end

	return #code
end

function formating.SubPositionToLinePosition(code--[[#: string]], start--[[#: number]], stop--[[#: number]])
	local line = 1
	local line_start = 1
	local line_stop = nil
	local within_start = 1
	local within_stop = #code
	local character_start = 1
	local character_stop = 1
	local line_pos = 1
	local char_pos = 1

	for i = 1, #code do
		local char = code:sub(i, i)

		if i == stop then
			line_stop = line
			character_stop = char_pos
		end

		if i == start then
			line_start = line
			within_start = line_pos
			character_start = char_pos
		end

		if char == "\n" then
			if line_stop then
				within_stop = i

				break
			end

			line = line + 1
			line_pos = i
			char_pos = 1
		else
			char_pos = char_pos + 1
		end
	end

	if line_start ~= line_stop then
		character_start = within_start
		character_stop = within_stop
	end

	return {
		character_start = character_start,
		character_stop = character_stop,
		line_start = line_start,
		line_stop = line_stop or line_start,
		sub_line_before = {within_start, start - 1},
		sub_line_after = {stop + 1, within_stop},
	}
end

do
	function formating.FormatMessage(msg--[[#: string]], ...)
		for i = 1, select("#", ...) do
			local arg = select(i, ...)

			if type(arg) == "table" then
				arg = formating.QuoteTokens(arg)
			else
				arg = formating.QuoteToken(arg or "?")
			end

			msg = stringx.replace(msg, "$" .. i, arg)
		end

		return msg
	end
end

local function find_all(
	lua_code--[[#: string]],
	start--[[#: number]],
	stop--[[#: number]],
	line_context--[[#: number]]
)
	local source_code_line_start = 1
	local source_code_line_stop = 1
	local line_stop = 1
	local line_start = 1
	local before_sub = 1
	local after_sub = #lua_code
	local source_code_char_start = 1
	local source_code_char_stop = 1

	do -- find the line start
		local line_count = 0

		for i = 1, start do
			local c = lua_code:sub(i, i)

			if c == "\n" then line_count = line_count + 1 end
		end

		source_code_line_start = line_count
	end

	do -- find the line start
		local line_count = 0

		for i = 1, stop do
			local c = lua_code:sub(i, i)

			if c == "\n" then line_count = line_count + 1 end
		end

		source_code_line_stop = line_count
	end

	do -- find the line stop
		local line_count = 0

		for i = 1, stop do
			local c = lua_code:sub(i, i)

			if c == "\n" then line_count = line_count + 1 end
		end

		line_stop = line_count
	end

	do
		local line_count = 0

		for i = start, 1, -1 do
			local c = lua_code:sub(i, i)

			if c == "\n" then line_count = line_count + 1 end

			if line_count >= line_context then
				before_sub = i + 1
				line_start = line_count - 1

				break
			end
		end
	end

	do
		local line_count = 0

		for i = stop, #lua_code do
			local c = lua_code:sub(i, i)

			if c == "\n" then line_count = line_count + 1 end

			if line_count >= line_context then
				after_sub = i

				break
			end
		end
	end

	do
		source_code_char_start = 0

		for i = 1, start do
			local c = lua_code:sub(i, i)

			if c == "\n" then
				source_code_char_start = 0
			else
				source_code_char_start = source_code_char_start + 1
			end
		end

		source_code_char_start = source_code_char_start - 1
	end

	do
		source_code_char_stop = 0

		for i = start, #lua_code do
			local c = lua_code:sub(i, i)

			if c == "\n" then
				source_code_char_stop = 0

				break
			else
				source_code_char_stop = source_code_char_stop + 1
			end
		end
	end

	local char_stop = 0
	local char_count = 0

	for i = before_sub, after_sub do
		if i > stop then char_stop = char_stop + 1 end

		local c = lua_code:sub(i, i)

		if c == "\n" or i == after_sub then
			if char_stop > 0 then
				source_code_char_stop = char_count - char_stop

				break
			end

			char_count = 0
		else
			char_count = char_count + 1
		end
	end

	return {
		source_code_line_start = source_code_line_start + 1,
		source_code_line_stop = source_code_line_stop + 1,
		source_code_char_start = source_code_char_start,
		source_code_char_stop = source_code_char_stop,
		before_sub = before_sub,
		after_sub = after_sub,
		line_pos = math.max((source_code_line_start - line_start) + 1, 1),
		line_start = math.max((source_code_line_start - line_start) + 1, 1),
		line_stop = math.max((source_code_line_start + line_stop) + 1, 1),
	}
end

local SEPARATOR = " | "
local ARROW = "->"

function formating.BuildSourceCodePointMessage(
	lua_code--[[#: string]],
	path--[[#: nil | string]],
	msg--[[#: string]],
	start--[[#: number]],
	stop--[[#: number]],
	line_context--[[#: number]]
)
	if #lua_code > 500000 then
		return "*cannot point to source code, too big*: " .. msg
	end

	if not lua_code:find("\n", nil, true) then
		-- this simplifies the below logic a lot..	
		lua_code = lua_code .. "\n"
	end

	line_context = (line_context or 2) * 2
	start = mathx.clamp(start or 1, 1, #lua_code)
	stop = mathx.clamp(stop or 1, 1, #lua_code)
	local data = find_all(lua_code, start, stop, line_context)
	local number_length = #tostring(data.line_stop)
	local line_pos = data.line_pos
	local lines = {}

	do
		local chars = {}

		for i = data.before_sub, data.after_sub do
			local char = lua_code:sub(i, i)

			if char == "\n" or i == data.after_sub then
				local line = table.concat(chars)
				local inside = i >= start and i <= stop
				local header = stringx.pad_left(tostring(line_pos), number_length, " ") .. SEPARATOR

				if
					data.source_code_line_start == line_pos and
					data.source_code_line_stop == line_pos
				then
					-- only spans one line
					local before = header .. line:sub(1, data.source_code_char_start)
					local between = line:sub(data.source_code_char_start + 1, data.source_code_char_stop)
					local after = line:sub(data.source_code_char_stop + 1, #line)
					table.insert(lines, before .. between .. after)
					table.insert(lines, (" "):rep(#before) .. ("^"):rep(#between + 1))
				elseif data.source_code_line_start == line_pos then
					-- multiple line span, first line
					local before = header .. line:sub(1, data.source_code_char_start)
					local after = line:sub(data.source_code_char_start + 1, #line)
					table.insert(lines, before .. after)
					table.insert(lines, (" "):rep(#before) .. ("^"):rep(#after))
				elseif data.source_code_line_stop == line_pos then
					-- multiple line span, last line
					local before = line:sub(1, data.source_code_char_stop)
					local after = line:sub(data.source_code_char_stop + 1, #line)
					table.insert(lines, header .. before .. after)
					table.insert(lines, (" "):rep(#header) .. ("^"):rep(#before + 1))
				elseif inside then
					-- multiple line span, in between start and stop lines
					local after = line
					table.insert(lines, header .. after)
					table.insert(lines, (" "):rep(#header) .. ("^"):rep(#after))
				else
					table.insert(lines, header .. line)
				end

				chars = {}
				line_pos = line_pos + 1
			else
				table.insert(chars, char)
			end
		end
	end

	local longest_line = 0

	for i, v in ipairs(lines) do
		if #v > longest_line then longest_line = #v end
	end

	table.insert(
		lines,
		1,
		(
				" "
			):rep(number_length + #SEPARATOR) .. (
				"_"
			):rep(longest_line - number_length - #SEPARATOR)
	)
	table.insert(
		lines,
		(
				" "
			):rep(number_length + #SEPARATOR) .. (
				"-"
			):rep(longest_line - number_length - #SEPARATOR)
	)

	if path then
		if path:sub(1, 1) == "@" then path = path:sub(2) end

		local msg = path .. ":" .. data.source_code_line_start .. ":" .. (
				data.source_code_char_start + 1
			)
		table.insert(lines, stringx.pad_left(ARROW, number_length, " ") .. SEPARATOR .. msg)
	end

	table.insert(lines, stringx.pad_left(ARROW, number_length, " ") .. SEPARATOR .. msg)
	return stringx.replace(table.concat(lines, "\n"), "\t", " ")
end

return formating
