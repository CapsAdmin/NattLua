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

function formating.LineCharToSubPos(code--[[#: string]], line--[[#: number]], character--[[#: number]])--[[#: number]]
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

do
	local sub_to_linechar--[[#: Map<|string, Map<|number, {number, number}|>|>]] = {}
	local linechar_to_sub--[[#: Map<|string, Map<|number, Map<|number, number|>|>|>]] = {}

	local function get_cache(code)
		if not sub_to_linechar[code] then
			sub_to_linechar[code] = {}--[[# as any]]
			linechar_to_sub[code] = {}--[[# as any]]
			local line = 1
			local char = 1

			for i = 1, #code do
				local c = code:sub(i, i)
				sub_to_linechar[code][i] = {line, char}
				linechar_to_sub[code][line] = linechar_to_sub[code][line] or {}
				linechar_to_sub[code][line][char] = i

				if c == "\n" then
					line = line + 1
					char = 1
				else
					char = char + 1
				end
			end
		end

		return sub_to_linechar[code], linechar_to_sub[code]
	end

	function formating.SubPosToLineCharCached(code--[[#: string]], start--[[#: number]], stop--[[#: number]])
		local cache = get_cache(code)--[[# as (any, any)]]
		local line_start, char_start = assert(cache[start][1]), assert(cache[start][2])
		local line_stop, char_stop = assert(cache[stop][1]), assert(cache[stop][2])
		return {
			character_start = char_start,
			character_stop = char_stop,
			line_start = line_start,
			line_stop = line_stop,
		}
	end

	function formating.LineCharToSubPosCached(code--[[#: string]], line--[[#: number]], character--[[#: number]])--[[#: number]]
		local _, cache = get_cache(code)--[[# as (any, any)]]
		
		line = math.min(math.max(1, line), #cache)
		character = math.min(math.max(1, character), #cache[line])

		return assert(cache[line][character])
	end
end

local function sub_pos_to_line_char(str, pos)
	local line = 1
	local char = 1

	for i = 1, pos do
		local c = str:sub(i, i)

		if i == pos then return line, char end

		if c == "\n" then
			line = line + 1
			char = 1
		else
			char = char + 1
		end
	end
end

function formating.SubPosToLineChar(code--[[#: string]], start--[[#: number]], stop--[[#: number]])
	local line_start, char_start = sub_pos_to_line_char(code, start)
	local line_stop, char_stop = sub_pos_to_line_char(code, stop)
	return {
		character_start = char_start,
		character_stop = char_stop,
		line_start = line_start,
		line_stop = line_stop,
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

local SEPARATOR = " | "
local ARROW = "->"
local TAB_WIDTH = (" "):rep(4)

function formating.BuildSourceCodePointMessage2(
	code--[[#: string]],
	start--[[#: number]],
	stop--[[#: number]],
	config--[[#: nil | {
		path = nil | string,
		messages = nil | List<|string|>,
		surrounding_line_count = nil | number,
		show_line_numbers = nil | boolean,
		show_box = nil | boolean,
	}]]
)
	config = config or {}
	config.surrounding_line_count = config.surrounding_line_count or 3

	if config.show_line_numbers == nil then config.show_line_numbers = true end

	if config.show_box == nil then config.show_box = true end

	start = mathx.clamp(start or 1, 1, #code)
	stop = mathx.clamp(stop or 1, 1, #code)

	if stop < start then start, stop = stop, start end

	local lines = {}
	local line = {}
	local line_start--[[#: number]]
	local line_stop--[[#: number]]
	local char_start--[[#: number]]
	local char_stop--[[#: number]]
	local source_code_char_start--[[#: number]]
	local source_code_char_stop--[[#: number]]

	for i = 1, #code do
		local char = code:sub(i, i)

		if i >= start then
			if not line_start then line_start = #lines + 1 end

			if not char_start then
				source_code_char_start = #line + 1
				char_start = #table.concat(line):gsub("\t", TAB_WIDTH) + 1
			end
		end

		if i >= stop then
			if not line_stop then line_stop = #lines + 1 end

			if not char_stop then
				source_code_char_stop = #line + 1
				char_stop = #table.concat(line):gsub("\t", TAB_WIDTH) + 1
			end
		end

		if char == "\n" or i == #code then
			if i == #code then table.insert(line, char) end

			table.insert(lines, table.concat(line))
			line = {}
		else
			table.insert(line, char)
		end
	end

	local start_line_context = math.max(line_start - config.surrounding_line_count, 1)
	local stop_line_context = math.min(line_stop + config.surrounding_line_count, #lines)
	local number_length = #tostring(stop_line_context)
	local annotated = {}

	for line_pos = start_line_context, stop_line_context do
		local line = lines[line_pos]:gsub("\t", TAB_WIDTH)
		local header = config.show_line_numbers == false and
			"" or
			stringx.pad_left(tostring(line_pos), number_length, " ") .. SEPARATOR

		if line_pos == line_start and line_pos == line_stop then
			-- only spans one line
			local before = line:sub(1, char_start - 1)
			local between = line:sub(char_start, char_stop)
			local after = line:sub(char_stop + 1, #line)

			if char_start > #line then between = between .. "\\n" end

			before = header .. before
			table.insert(annotated, before .. between .. after)
			table.insert(annotated, (" "):rep(#before) .. ("^"):rep(#between))
		elseif line_pos == line_start then
			-- multiple line span, first line
			local before = line:sub(1, char_start - 1)
			local after = line:sub(char_start, #line)

			-- newline
			if char_start > #line then after = "\\n" end

			before = header .. before
			table.insert(annotated, before .. after)
			table.insert(annotated, (" "):rep(#before) .. ("^"):rep(#after))
		elseif line_pos == line_stop then
			-- multiple line span, last line
			local before = line:sub(1, char_stop)
			local after = line:sub(char_stop + 1, #line)
			table.insert(annotated, header .. before .. after)
			table.insert(annotated, (" "):rep(#header) .. ("^"):rep(#before))
		elseif line_pos > line_start and line_pos < line_stop then
			-- multiple line span, in between start and stop lines
			local after = line
			table.insert(annotated, header .. after)
			table.insert(annotated, (" "):rep(#header) .. ("^"):rep(#after))
		else
			table.insert(annotated, header .. line)
		end
	end

	if config.show_box then
		local longest_line = 0

		for i, v in ipairs(annotated) do
			if #v > longest_line then longest_line = #v end
		end

		table.insert(
			annotated,
			1,
			(
					" "
				):rep(number_length + #SEPARATOR) .. (
					"_"
				):rep(longest_line - number_length - #SEPARATOR)
		)
		table.insert(
			annotated,
			(
					" "
				):rep(number_length + #SEPARATOR) .. (
					"-"
				):rep(longest_line - number_length - #SEPARATOR)
		)
	end

	local header = config.show_line_numbers == false and
		"" or
		stringx.pad_left(ARROW, number_length, " ") .. SEPARATOR

	if config.path then
		local path = config.path

		if path:sub(1, 1) == "@" then path = path:sub(2) end

		local msg = path .. ":" .. line_start .. ":" .. source_code_char_start
		table.insert(annotated, header .. msg)
	end

	if config.messages then
		for _, msg in ipairs(config.messages) do
			table.insert(annotated, header .. msg)
		end
	end

	return table.concat(annotated, "\n"):gsub("\t", TAB_WIDTH)
end

function formating.BuildSourceCodePointMessage(
	lua_code--[[#: string]],
	path--[[#: nil | string]],
	msg--[[#: string]],
	start--[[#: number]],
	stop--[[#: number]],
	line_context--[[#: number]]
)
	line_context = line_context or 4
	return formating.BuildSourceCodePointMessage2(
		lua_code,
		start,
		stop,
		{
			path = path,
			messages = {msg},
			surrounding_line_count = line_context,
		}
	)
end

return formating
