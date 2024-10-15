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
			local arg = select(i, ...)--[[# as string | List<|string|>]]

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
		if #lua_code > 500000 then
			return "*cannot point to source code, too big*: " .. msg
		end

		if not lua_code:find("\n", nil, true) then
			-- this simplifies the below logic a lot..	
			lua_code = lua_code .. "\n"
		end

		size = size or 2
		start = mathx.clamp(start or 1, 1, #lua_code)
		stop = mathx.clamp(stop or 1, 1, #lua_code)
		local point_line_start
		local line_start
		local character_start = 1
		local line_stop
		local before_sub = 1
		local after_sub = #lua_code

		do
			local line_count = 1

			for i = 1, stop do
				local c = lua_code:sub(i, i)

				if c == "\n" then line_count = line_count + 1 end

				if i == start then
					line_start = line_count
					point_line_start = line_count
				end
			end

			line_stop = line_count
			local line_count = 1

			for i = start, 1, -1 do
				local c = lua_code:sub(i, i)

				if c == "\n" then line_count = line_count + 1 end

				if line_count >= 4 then
					before_sub = i + 1
					line_start = line_count - 1

					break
				end
			end

			local line_count = 1

			for i = stop, #lua_code do
				local c = lua_code:sub(i, i)

				if c == "\n" then line_count = line_count + 1 end

				if line_count >= 4 then
					after_sub = i

					break
				end
			end
		end

		local line_pos = point_line_start - line_start + 1
		local lines = {}
		local str = ""
		local char_start = 0
		local char_stop = 0
		local captured_start = false
		local captured_stop = false

		for i = before_sub, after_sub do
			if not captured_start and i >= start then char_start = char_start + 1 end

			if not captured_stop and i >= stop then char_stop = char_stop + 1 end

			local c = lua_code:sub(i, i)

			if c == "\n" then
				local start_
				local stop_

				if char_start > 0 and not captured_start then
					start_ = #str - char_start + 1
					character_start = start_
				end

				if char_stop > 0 and not captured_stop then
					stop_ = #str - char_stop + 1
				end

				table.insert(
					lines,
					{
						str = str,
						start = start_,
						stop = stop_,
						inside = i >= start and i <= stop,
						line_pos = line_pos,
					}
				)

				if char_start > 0 then captured_start = true end

				if char_stop > 0 then captured_stop = true end

				str = ""
				line_pos = line_pos + 1
			else
				str = str .. c
			end
		end

		if #str > 0 then
			local start_
			local stop_

			if char_start > 0 and not captured_start then
				start_ = #str - char_start + 1
				character_start = start_
			end

			if char_stop > 0 and not captured_stop then stop_ = #str - char_stop end

			table.insert(
				lines,
				{str = str, start = start_, stop = stop_, inside = false, line_pos = line_pos}
			)

			if char_start > 0 then captured_start = true end

			if char_stop > 0 then captured_stop = true end

			str = ""
			line_pos = line_pos + 1
		end

		local separator = " | "
		local arrow = "->"
		local number_length = 1

		for i, v in ipairs(lines) do
			if #tostring(v.line_pos) > number_length then
				number_length = #tostring(v.line_pos)
			end
		end

		local str = {}

		for i, line in ipairs(lines) do
			local header = stringx.pad_left(tostring(line.line_pos), number_length, " ") .. separator

			if line.start and line.stop then
				-- only spans one line
				local before = header .. line.str:sub(1, line.start)
				local between = line.str:sub(line.start + 1, line.stop)
				local after = line.str:sub(line.stop + 1, #line.str)
				table.insert(str, before .. between .. after)
				table.insert(str, (" "):rep(#before) .. ("^"):rep(#between + 1))
			elseif line.start then
				-- multiple line span, first line
				local before = header .. line.str:sub(1, line.start)
				local after = line.str:sub(line.start + 1, #line.str)
				table.insert(str, before .. after)
				table.insert(str, (" "):rep(#before) .. ("^"):rep(#after))
			elseif line.stop then
				-- multiple line span, last line
				local before = line.str:sub(1, line.stop)
				local after = line.str:sub(line.stop + 1, #line.str)
				table.insert(str, header .. before .. after)
				table.insert(str, (" "):rep(#header) .. ("^"):rep(#before + 1))
			elseif line.inside then
				-- multiple line span, in between start and stop lines
				local after = line.str
				table.insert(str, header .. after)
				table.insert(str, (" "):rep(#header) .. ("^"):rep(#after))
			else
				table.insert(str, header .. line.str)
			end
		end

		local longest_line = 0

		for i, v in ipairs(str) do
			if #v > longest_line then longest_line = #v end
		end

		table.insert(
			str,
			1,
			(
					" "
				):rep(number_length + #separator) .. (
					"_"
				):rep(longest_line - number_length - #separator)
		)
		table.insert(
			str,
			(
					" "
				):rep(number_length + #separator) .. (
					"-"
				):rep(longest_line - number_length - #separator)
		)

		if path then
			if path:sub(1, 1) == "@" then path = path:sub(2) end

			local msg = path .. ":" .. point_line_start .. ":" .. (character_start + 1)
			table.insert(str, stringx.pad_left(arrow, number_length, " ") .. separator .. msg)
		end

		table.insert(str, stringx.pad_left(arrow, number_length, " ") .. separator .. msg)
		local str = table.concat(str, "\n")
		str = stringx.replace(str, "\t", " ")
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
