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

				if char_pos == character then return i end

				char_pos = char_pos + 1
			end

			return i
		end

		if c == "\n" then line_pos = line_pos + 1 end
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
	-- TODO: wtf am i doing here?
	local args--[[#: List<|string | List<|string|>|>]]
	local fmt = function(str--[[#: string]])
		local num = tonumber(str)

		if not num then error("invalid format argument " .. str) end

		if type(args[num]) == "table" then return formating.QuoteTokens(args[num]) end

		return formating.QuoteToken(args[num] or "?")
	end

	function formating.FormatMessage(msg--[[#: string]], ...)
		args = {...}
		msg = msg:gsub("$(%d)", fmt)
		return msg
	end
end

do
	local function find_position_after_lines(str--[[#: string]], line_count--[[#: number]])
		local count = 0

		for i = 1, #str do
			local char = str:sub(i, i)

			if char == "\n" then count = count + 1 end

			if count >= line_count then return i - 1 end
		end

		return #str
	end

	local MAX_WIDTH = 127

	function formating.BuildSourceCodePointMessage(
		lua_code--[[#: string]],
		path--[[#: nil | string]],
		msg--[[#: string]],
		start--[[#: number]],
		stop--[[#: number]],
		size--[[#: number]]
	)
		if not start then debug.trace() end

		if #lua_code > 500000 then return "code too big: " .. msg end

		do
			local new_str = ""
			local pos = 1

			for i, chunk in ipairs(stringx.length_split(lua_code, MAX_WIDTH)) do
				if pos < start and i > 1 then start = start + 1 end

				if pos < stop and i > 1 then stop = stop + 1 end

				new_str = new_str .. chunk .. "\n"
				pos = pos + #chunk
			end

			lua_code = new_str
		end

		size = size or 2
		start = mathx.clamp(start or 1, 1, #lua_code)
		stop = mathx.clamp(stop or 1, 1, #lua_code)
		local data = formating.SubPositionToLinePosition(lua_code, start, stop)
		local code_before = lua_code:sub(1, data.sub_line_before[1] - 1) -- remove the newline
		local code_between = lua_code:sub(data.sub_line_before[1] + 1, data.sub_line_after[2] - 1)
		local code_after = lua_code:sub(data.sub_line_after[2] + 1, #lua_code) -- remove the newline
		code_before = code_before:reverse():sub(1, find_position_after_lines(code_before:reverse(), size)):reverse()
		code_after = code_after:sub(1, find_position_after_lines(code_after, size))
		local lines_before = stringx.split(code_before, "\n")
		local lines_between = stringx.split(code_between, "\n")
		local lines_after = stringx.split(code_after, "\n")
		local total_lines = #lines_before + #lines_between + #lines_after
		local number_length = #tostring(total_lines)
		local lines = {}
		local i = data.line_start - #lines_before

		for _, line in ipairs(lines_before) do
			table.insert(lines, stringx.pad_left(tostring(i), number_length, " ") .. " | " .. line)
			i = i + 1
		end

		for i2, line in ipairs(lines_between) do
			local prefix = stringx.pad_left(tostring(i), number_length, " ") .. " | "
			table.insert(lines, prefix .. line)

			if #lines_between > 1 then
				if i2 == 1 then
					-- first line or the only line
					local length_before = data.sub_line_before[2] - data.sub_line_before[1]
					local arrow_length = #line - length_before
					table.insert(lines, (" "):rep(#prefix + length_before) .. ("^"):rep(arrow_length))
				elseif i2 == #lines_between then
					-- last line
					local length_before = data.sub_line_after[2] - data.sub_line_after[1]
					local arrow_length = #line - length_before
					table.insert(lines, (" "):rep(#prefix) .. ("^"):rep(arrow_length))
				else
					-- lines between
					table.insert(lines, (" "):rep(#prefix) .. ("^"):rep(#line))
				end
			else
				-- one line
				local length_before = data.sub_line_before[2] - data.sub_line_before[1]
				local length_after = data.sub_line_after[2] - data.sub_line_after[1]
				local arrow_length = #line - length_before - length_after
				table.insert(
					lines,
					(" "):rep(#prefix + length_before) .. ("^"):rep(arrow_length--[[# as number]])
				) -- TODO
			end

			i = i + 1
		end

		for _, line in ipairs(lines_after) do
			table.insert(lines, stringx.pad_left(tostring(i), number_length, " ") .. " | " .. line)
			i = i + 1
		end

		local longest_line = 0

		for _, line in ipairs(lines) do
			if #line > longest_line then longest_line = #line end
		end

		longest_line = math.min(longest_line, MAX_WIDTH)
		table.insert(
			lines,
			1,
			(" "):rep(number_length + 3) .. ("_"):rep(longest_line - number_length + 1)
		)
		table.insert(
			lines,
			(" "):rep(number_length + 3) .. ("-"):rep(longest_line - number_length + 1)
		)

		if path then
			if path:sub(1, 1) == "@" then path = path:sub(2) end

			local msg = path .. ":" .. data.line_start .. ":" .. data.character_start
			table.insert(lines, stringx.pad_left("->", number_length, " ") .. " | " .. msg)
		end

		table.insert(lines, stringx.pad_left("->", number_length, " ") .. " | " .. msg)
		local str = table.concat(lines, "\n")
		str = str:gsub("\t", " ")
		return str
	end
end

function formating.TableToColumns(
	title--[[#: string]],
	tbl--[[#: Map<|any, any|>]],
	columns--[[#: List<|
		{
			length = number,
			friendly = string,
			tostring = Function,
			key = string,
		}
	|>]],
	check--[[#: Function | nil]],
	sort_key--[[#: string | Function]]
)
	local top = {}

	for k, v in pairs(tbl) do
		if not check or check(v) then table.insert(top, {key = k, val = v}) end
	end

	if type(sort_key) == "function" then
		table.sort(top, function(a, b)
			return sort_key(a.val, b.val)
		end)
	else
		table.sort(top, function(a, b)
			return a.val[sort_key] > b.val[sort_key]
		end)
	end

	local max_lengths = {}
	local temp = {}

	for _, column in ipairs(top) do
		for key, data in ipairs(columns) do
			data.tostring = data.tostring or function(...)
				return ...
			end
			data.friendly = data.friendly or data.key
			max_lengths[data.key] = max_lengths[data.key] or 0
			local str = tostring(data.tostring(column.val[data.key], column.val, top))
			column.str = column.str or {}
			column.str[data.key] = str

			if #str > max_lengths[data.key] then max_lengths[data.key] = #str end

			temp[key] = data
		end
	end

	columns = temp
	local width = 0

	for _, v in pairs(columns) do
		if assert(max_lengths[v.key]) > #v.friendly then
			v.length = max_lengths[v.key]
		else
			v.length = #v.friendly + 1
		end

		width = width + #v.friendly + max_lengths[v.key] - 2
	end

	local out = " "
	out = out .. ("_"):rep(width - 1) .. "\n"
	out = out .. "|" .. (
			" "
		):rep(width / 2 - math.floor(#title / 2)) .. title .. (
			" "
		):rep(math.floor(width / 2) - #title + math.floor(#title / 2)) .. "|\n"
	out = out .. "|" .. ("_"):rep(width - 1) .. "|\n"

	for _, v in ipairs(columns) do
		out = out .. "| " .. v.friendly .. ": " .. (
				" "
			):rep(-#v.friendly + max_lengths[v.key] - 1) -- 2 = : + |
	end

	out = out .. "|\n"

	for _, v in ipairs(columns) do
		out = out .. "|" .. ("_"):rep(v.length + 2)
	end

	out = out .. "|\n"

	for _, v in ipairs(top) do
		for _, column in ipairs(columns) do
			out = out .. "| " .. assert(v.str)[column.key] .. (
					" "
				):rep(-#assert(v.str)[column.key] + column.length + 1)
		end

		out = out .. "|\n"
	end

	out = out .. "|"
	out = out .. ("_"):rep(width - 1) .. "|\n"
	return out
end

return formating