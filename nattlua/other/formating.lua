--[[HOTRELOAD
	run_test("test/tests/nattlua/code_pointing.lua")
]]
--ANALYZE
local math = _G.math
local table = _G.table
local type = _G.type
local tonumber = _G.tonumber
local tostring = _G.tostring
local error = _G.error
local ipairs = _G.ipairs
local stringx = require("nattlua.other.string")
local formating = {}
local is_plain = false
local is_markdown = false

function formating.SetPlain(b--[[#: boolean]])
	is_plain = b
end

function formating.SetMarkdown(b--[[#: boolean]])
	is_markdown = b
end

local function try_to_markdown_link(msg)
	if msg:sub(1, 1) == "[" then return msg end

	local path, line = msg:match("^([^:]+):(%d+)")

	if path and (path:find("/") or path:find("%.lua") or path:find("%.nlua")) then
		if path:sub(1, 1) == "@" then path = path:sub(2) end

		local link = path

		if line and line ~= "" then
			link = link .. "#L" .. line
		end

		return "[" .. msg .. "](" .. link .. ")"
	end

	-- check for at stack traceback: lines and other lines that contains paths
	local out = msg:gsub("([%w%._%-%/]+):(%d+)", function(path, line)
		if path:find("/") or path:find("%.lua") or path:find("%.nlua") then
			return "[" .. path .. ":" .. line .. "](" .. path .. "#L" .. line .. ")"
		end
	end)

	if out ~= msg then return out end

	return msg
end

local assert = _G.assert
local select = _G.select

function formating.QuoteToken(str--[[#: string]])--[[#: string]]
	if is_markdown then return "`" .. str .. "`" end

	if is_plain then return "'" .. str .. "'" end

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
	local function sub_pos_to_line_char(str--[[#: string]], pos--[[#: number]])--[[#: number, number]]
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

		return assert(sub_to_linechar[code]), assert(linechar_to_sub[code])
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
	function formating.FormatMessage(msg--[[#: string]], ...--[[#: ...(string | List<|string|>)]])
		for i = 1, select("#", ...) do
			local arg = select(i, ...)--[[# as string | List<|string|> or "?"]]

			if type(arg) == "table" then
				arg = formating.QuoteTokens(arg)
			elseif type(arg) == "string" then
				if not arg:find("\n", nil, true) then
					arg = formating.QuoteToken(tostring(arg))
				else
					arg = tostring(arg)
				end
			else
				arg = tostring(arg)
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
	local local_start = start
	local local_stop
	local before
	local after
	local mid = str:sub(start, stop)
	local line_offset = 0
	local line_start = 1
	local line_stop = 1
	local context_start
	local lines = {}
	local line = {}
	local char_start
	local char_stop
	local source_code_char_start
	local source_code_char_stop
	local line_pos = 1
	local source_char_pos = 0

	do
		local line_pos = -1
		before = {}

		for i = start - 1, 1, -1 do
			local c = str:sub(i, i)

			if c == "\n" or c == 1 then line_pos = line_pos + 1 end

			if line_pos == context_line_count then
				context_start = i
				local_start = start - context_start

				for i = 1, context_start do
					if str:byte(i) == 10 then line_offset = line_offset + 1 end
				end

				break
			end

			before[-i + start] = c
		end

		before = table.concat(before):reverse()
	end

	do
		local line_pos = -1
		after = {}

		for i = stop + 1, #str do
			local c = str:sub(i, i)

			if c == "\n" or c == #str then line_pos = line_pos + 1 end

			if line_pos == context_line_count then break end

			after[i - stop] = c
		end

		after = table.concat(after)
	end

	local local_str = before .. mid .. after
	local local_stop = local_start + (stop - start)

	for i = 1, #local_str do
		local c = local_str:sub(i, i)

		if c ~= "\n" then
			if c == "\t" then
				for i = 1, #TAB_WIDTH do
					table.insert(line, " ")
				end
			else
				table.insert(line, c)
			end

			source_char_pos = source_char_pos + 1
		end

		if c == "\n" or i == #local_str then
			table.insert(lines, table.concat(line))
			line_pos = line_pos + 1
			line = {}
			source_char_pos = 0
		end

		if i == local_start then
			line_start = line_pos
			source_code_char_start = source_char_pos
			char_start = #line
		end

		if i == local_stop then
			line_stop = line_pos
			char_stop = #line
			source_code_char_stop = source_char_pos
		end
	end

	return {
		lines = lines,
		line_offset = assert(line_offset),
		line_start = assert(line_start),
		line_stop = assert(line_stop),
		char_start = assert(char_start),
		char_stop = assert(char_stop),
		source_code_char_start = assert(source_code_char_start),
		source_code_char_stop = assert(source_code_char_stop),
	}
end

local function clamp(num--[[#: number]], min--[[#: number]], max--[[#: number]])
	return math.min(math.max(num, min), max)
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

	start = clamp(start or 1, 1, #code)
	stop = clamp(stop or 1, 1, #code)

	if stop < start then start, stop = stop, start end

	local d = calculate_text_positions(code, start, stop, config.surrounding_line_count)
	local number_length = #tostring(d.line_offset + #d.lines)
	local annotated = {}

	-- this will be replaced later
	if config.show_box then table.insert(annotated, "") end

	for i, line in ipairs(d.lines) do
		local header = config.show_line_numbers == false and
			"" or
			stringx.pad_left(tostring(i + d.line_offset), number_length, " ") .. SEPARATOR

		if i == d.line_start and i == d.line_stop then
			-- only spans one line
			local before = line:sub(1, d.char_start - 1)
			local between = line:sub(d.char_start, d.char_stop)
			local after = line:sub(d.char_stop + 1, #line)

			if d.char_start > #line then between = between .. "\\n" end

			before = header .. before
			table.insert(annotated, before .. between .. after)
			table.insert(annotated, (" "):rep(#before) .. ("^"):rep(#between))
		elseif i == d.line_start then
			-- multiple line span, first line
			local before = line:sub(1, d.char_start - 1)
			local after = line:sub(d.char_start, #line)

			-- newline
			if d.char_start > #line then after = "\\n" end

			before = header .. before
			table.insert(annotated, before .. after)
			table.insert(annotated, (" "):rep(#before) .. ("^"):rep(#after))
		elseif i == d.line_stop then
			-- multiple line span, last line
			local before = line:sub(1, d.char_stop)
			local after = line:sub(d.char_stop + 1, #line)
			table.insert(annotated, header .. before .. after)
			table.insert(annotated, (" "):rep(#header) .. ("^"):rep(#before))
		elseif i > d.line_start and i < d.line_stop then
			-- multiple line span, in between start and stop lines
			local after = line
			table.insert(annotated, header .. after)
			table.insert(annotated, (" "):rep(#header) .. ("^"):rep(#after))
		else
			table.insert(annotated, header .. line)
		end
	end

	if config.show_box and not is_markdown then
		local longest_line = 0

		for i, v in ipairs(annotated) do
			if #v > longest_line then longest_line = #v end
		end

		annotated[1] = (
				" "
			):rep(number_length + #SEPARATOR) .. (
				"_"
			):rep(longest_line - number_length - #SEPARATOR)
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

	if is_markdown then
		local out = ""
		local main_link = nil

		if config.path then
			local path = config.path

			if path:sub(1, 1) == "@" then path = path:sub(2) end

			local line = (d.line_start + d.line_offset)
			local col = d.source_code_char_start
			main_link = "[" .. path .. ":" .. line .. ":" .. col .. "](" .. path .. "#L" .. line .. ")"
			out = out .. main_link .. "\n\n"
		end

		if config.messages then
			for _, msg in ipairs(config.messages) do
				local transformed = try_to_markdown_link(msg)

				if transformed ~= msg then
					-- if the location is exactly the same as main_link, don't repeat it
					if transformed ~= main_link then
						out = out .. transformed .. "\n\n"
					end
				else
					local label = msg:gsub("^### ", "")

				if main_link then
					local link = main_link:match("%((.-)%)")
					if link then
						out = out .. "[" .. label .. "](" .. link .. ")\n\n"
					else
						out = out .. "**" .. label .. "**\n\n"
					end
				else
					out = out .. "**" .. label .. "**\n\n"
				end
				end
			end
		end

		out = out .. "\n```lua\n" .. table.concat(annotated, "\n"):gsub("\t", TAB_WIDTH):gsub(" +(\n)", "%1"):gsub(" +$", "") .. "\n```\n"

		return out
	end

	if config.path then
		local path = config.path

		if path:sub(1, 1) == "@" then path = path:sub(2) end

		local msg = path .. ":" .. (d.line_start + d.line_offset) .. ":" .. d.source_code_char_start
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
