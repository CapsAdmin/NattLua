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
	local function sub_pos_to_line_char(str--[[#: string]], pos--[[#: number]])--[[#: number,number]]
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

		return line, char
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
end

do
	local sub_to_linechar--[[#: Map<|string, Map<|number, {number, number}|>|>]] = {}
	local linechar_to_sub--[[#: Map<|string, Map<|number, Map<|number, number|>|>|>]] = {}

	local function get_cache(code--[[#: string]])
		if not sub_to_linechar[code] then
			sub_to_linechar[code] = {}--[[# as sub_to_linechar[string] ~ nil]] -- TODO
			linechar_to_sub[code] = {}--[[# as linechar_to_sub[string] ~ nil]]
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
		start = math.min(math.max(1, start), #code)
		stop = math.min(math.max(1, stop), #code)
		local cache = get_cache(code)
		local start = assert(cache[start])
		local stop = assert(cache[stop])
		return {
			character_start = assert(start[2]),
			character_stop = assert(stop[2]),
			line_start = assert(start[1]),
			line_stop = assert(stop[1]),
		}
	end

	function formating.LineCharToSubPosCached(code--[[#: string]], line--[[#: number]], character--[[#: number]])--[[#: number]]
		local _, cache = get_cache(code)
		line = math.min(math.max(1, line), #cache)
		assert(cache[line])
		character = math.min(math.max(1, character), #cache[line])
		return assert(cache[line][character])
	end
end

do
	function formating.FormatMessage(msg--[[#: string]], ...--[[#: ...any]])
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

local function calculate_text_positions(
	str--[[#: string]],
	start--[[#: number]],
	stop--[[#: number]],
	context_line_count--[[#: number]]
)
	local lines = {}
	local current_line = {}
	local line_start--[[#: number | nil]]
	local line_stop--[[#: number | nil]]
	local char_start--[[#: number | nil]]
	local char_stop--[[#: number | nil]]
	local source_code_char_start--[[#: number | nil]]
	local source_code_char_stop--[[#: number | nil]]

	for i = 1, #str do
		local char = str:sub(i, i)

		if i == start then
			line_start = #lines + 1
			source_code_char_start = #current_line + 1
			char_start = #table.concat(current_line):gsub("\t", TAB_WIDTH) + 1
		end

		if i == stop then
			line_stop = #lines + 1
			source_code_char_stop = #current_line + 1
			char_stop = #table.concat(current_line):gsub("\t", TAB_WIDTH) + 1
		end

		if char == "\n" or i == #str then
			if i == #str then table.insert(current_line, char) end

			table.insert(lines, (table.concat(current_line):gsub("\t", TAB_WIDTH)))
			current_line = {}
		else
			table.insert(current_line, char)
		end
	end

	local start_line_context = math.max(line_start - context_line_count, 1)
	local stop_line_context = math.min(line_stop + context_line_count, #lines)
	local start_line_context2
	local stop_line_context2

	do
		local line_pos = 1

		for i = start, 1, -1 do
			local char = str:sub(i, i)

			if char == "\n" then line_pos = line_pos + 1 end

			if line_pos == context_line_count or i == 1 then
				for i = 1, i do
					local char = str:sub(i, i)

					if char == "\n" then line_pos = line_pos + 1 end
				end

				start_line_context2 = math.max(line_pos - context_line_count - 1, 1)
				assert(start_line_context2 == start_line_context)

				break
			end
		end
	end

	do
		local line_pos = 1

		for i = stop, #str do
			local char = str:sub(i, i)

			if char == "\n" then line_pos = line_pos + 1 end

			if line_pos == context_line_count then
				line_pos = 1

				for i = 1, i do
					local char = str:sub(i, i)

					if char == "\n" then line_pos = line_pos + 1 end
				end

				stop_line_context2 = line_pos + 1
				assert(stop_line_context2 == stop_line_context, "???")

				break
			end
		end
	end

	for i = 1, start_line_context - 1 do
		lines[i] = nil
	end

	for i = stop_line_context + 1, #lines do
		lines[i] = nil
	end

	return {
		start_line_context = start_line_context,
		stop_line_context = stop_line_context,
		lines = lines,
		line_start = line_start,
		line_stop = line_stop,
		char_start = char_start,
		char_stop = char_stop,
		source_code_char_start = assert(source_code_char_start),
		source_code_char_stop = assert(source_code_char_stop),
	}
end

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

	local d = calculate_text_positions(code, start, stop, config.surrounding_line_count)
	local number_length = #tostring(d.stop_line_context)
	local annotated = {}

	for line_pos = d.start_line_context, d.stop_line_context do
		local line = d.lines[line_pos]
		local header = config.show_line_numbers == false and
			"" or
			stringx.pad_left(tostring(line_pos), number_length, " ") .. SEPARATOR

		if line_pos == d.line_start and line_pos == d.line_stop then
			-- only spans one line
			local before = line:sub(1, d.char_start - 1)
			local between = line:sub(d.char_start, d.char_stop)
			local after = line:sub(d.char_stop + 1, #line)

			if d.char_start > #line then between = between .. "\\n" end

			before = header .. before
			table.insert(annotated, before .. between .. after)
			table.insert(annotated, (" "):rep(#before) .. ("^"):rep(#between))
		elseif line_pos == d.line_start then
			-- multiple line span, first line
			local before = line:sub(1, d.char_start - 1)
			local after = line:sub(d.char_start, #line)

			-- newline
			if d.char_start > #line then after = "\\n" end

			before = header .. before
			table.insert(annotated, before .. after)
			table.insert(annotated, (" "):rep(#before) .. ("^"):rep(#after))
		elseif line_pos == d.line_stop then
			-- multiple line span, last line
			local before = line:sub(1, d.char_stop)
			local after = line:sub(d.char_stop + 1, #line)
			table.insert(annotated, header .. before .. after)
			table.insert(annotated, (" "):rep(#header) .. ("^"):rep(#before))
		elseif line_pos > d.line_start and line_pos < d.line_stop then
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

		local msg = path .. ":" .. d.line_start .. ":" .. d.source_code_char_start
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
