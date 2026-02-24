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
local ansi = require("nattlua.other.ansi")
local formating = {}
local is_plain = false
local is_markdown = false
local is_color = ansi.is_supported()

function formating.SetPlain(b--[[#: boolean]])
	is_plain = b
end

function formating.SetMarkdown(b--[[#: boolean]])
	is_markdown = b
end

function formating.SetColor(b--[[#: boolean]])
	is_color = b
end

local function try_to_markdown_link(msg)
	if msg:sub(1, 1) == "[" then return msg end

	local path, line = msg:match("^([^:]+):(%d+)")

	if path and (path:find("/") or path:find("%.lua") or path:find("%.nlua")) then
		if path:sub(1, 1) == "@" then path = path:sub(2) end

		local link = path

		if line and line ~= "" then link = link .. "#L" .. line end

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

			for i = i, i + character - 1 do
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
-- Maximum source-content width (columns) before the context around the
-- highlighted span is truncated with ellipsis markers.
local MAX_CONTENT_WIDTH = 100
local ELLIPSIS = "..."

-- Trim the text surrounding a highlighted span so the total display width
-- stays within MAX_CONTENT_WIDTH.  `before` / `between` / `after` are the
-- three plain-text segments of the source line (gutter NOT included).
-- Returns the three segments, possibly with `...` prepended/appended.
local function truncate_span(before--[[#: string]], between--[[#: string]], after--[[#: string]])
	if #before + #between + #after <= MAX_CONTENT_WIDTH then
		return before, between, after
	end

	-- Keep `between` untouched; divide remaining space evenly for context.
	local space = math.max(0, MAX_CONTENT_WIDTH - #between - 2 * #ELLIPSIS)
	local before_keep = math.ceil(space / 2)
	local after_keep = space - before_keep
	local new_before

	if #before > before_keep + #ELLIPSIS then
		new_before = ELLIPSIS .. before:sub(#before - before_keep + 1)
	else
		new_before = before
	end

	local new_after

	if #after > after_keep + #ELLIPSIS then
		new_after = after:sub(1, after_keep) .. ELLIPSIS
	else
		new_after = after
	end

	return new_before, between, new_after
end

-- ── Syntax highlighting ──────────────────────────────────────────────────────
-- Tokenize str for syntax highlighting.  Uses the NattLua lexer lazily (via
-- pcall) to avoid the circular dependency formating → lexer → token → formating.
-- Returns a list of {start, stop, color} byte-indexed spans (relative to str).
local function get_highlight_spans(str--[[#: string]])
	local ok_lex, Lexer_mod = pcall(require, "nattlua.lexer.lexer")
	local ok_code, Code_mod = pcall(require, "nattlua.code")

	if not ok_lex or not ok_code then return {} end

	local Lexer_new = Lexer_mod.New
	local Code_new = Code_mod.New

	if not Lexer_new or not Code_new then return {} end

	local ok_tok, tokens = pcall(function()
		return Lexer_new(Code_new(str, "@highlight")):GetTokens()
	end)

	if not ok_tok then return {} end

	local spans = {}

	for _, tk in ipairs(tokens--[[# as any]]) do
		local color
		local t = tk.type

		if t == "letter" and tk.sub_type then
			-- recognised keyword
			color = ansi.bold_bright_cyan
		elseif t == "string" then
			color = ansi.bright_green
		elseif t == "number" then
			color = ansi.bright_yellow
		elseif t == "line_comment" or t == "multiline_comment" or t == "comment_escape" then
			color = ansi.dim
		elseif t == "symbol" then
			color = ansi.bright_blue
		elseif t == "analyzer_debug_code" or t == "parser_debug_code" then
			color = ansi.dim .. ansi.magenta
		end

		if color then
			spans[#spans + 1] = {start = tk.start, stop = tk.stop, color = color}
		end
	end

	return spans
end

-- Given local_str and its highlight spans (byte-indexed), return a list of
-- colored line strings that parallel d.lines (newlines as separators, tabs
-- already expanded to TAB_WIDTH spaces).
local function build_colored_lines(str--[[#: string]], spans--[[#: any]])
	-- Build a flat event list sorted by byte position:
	--   {pos=n, color=string}  → open color at byte n
	--   {pos=n, color=false}   → reset (close) at byte n
	local events = {}

	for _, span in ipairs(spans) do
		events[#events + 1] = {pos = span.start, color = span.color}
		-- reset fires on the byte AFTER the token ends
		events[#events + 1] = {pos = span.stop + 1, color = false}
	end

	table.sort(events, function(a, b)
		return a.pos < b.pos
	end)

	local colored_lines = {}
	local cur_line = {}
	local cur_color = "" -- currently active ANSI code
	local ei = 1 -- event index
	for i = 1, #str do
		-- Fire events at this byte position (multiple spans can start/end here)
		while ei <= #events and events[ei].pos == i do
			local ev = events[ei]

			if ev.color then
				cur_color = ev.color
				cur_line[#cur_line + 1] = ev.color
			else
				cur_color = ""
				cur_line[#cur_line + 1] = ansi.reset
			end

			ei = ei + 1
		end

		local c = str:sub(i, i)

		if c == "\n" then
			-- Close any open color before the newline so it doesn't bleed
			if cur_color ~= "" then
				cur_line[#cur_line + 1] = ansi.reset
				cur_color = ""
			end

			colored_lines[#colored_lines + 1] = table.concat(cur_line)
			cur_line = {}
		elseif c == "\t" then
			cur_line[#cur_line + 1] = TAB_WIDTH
		else
			cur_line[#cur_line + 1] = c
		end
	end

	-- Flush last line (string without trailing newline)
	if cur_color ~= "" then cur_line[#cur_line + 1] = ansi.reset end

	colored_lines[#colored_lines + 1] = table.concat(cur_line)
	return colored_lines
end

local function calculate_text_positions(
	str--[[#: string]],
	start--[[#: number]],
	stop--[[#: number]],
	context_line_count--[[#: number]]
)
	local local_start = start
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

			if c == "\n" then line_pos = line_pos + 1 end

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

			if c == "\n" then line_pos = line_pos + 1 end

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
				-- Capture position BEFORE expanding the tab so char_start/stop
				-- point to the first space of the expansion, not the last.
				-- Add 1 to source_char_pos to match the increment below.
				if i == local_start then
					line_start = line_pos
					source_code_char_start = source_char_pos + 1
					char_start = #line + 1
				end

				if i == local_stop then
					line_stop = line_pos
					source_code_char_stop = source_char_pos + 1
					char_stop = #line + #TAB_WIDTH
				end

				for _ = 1, #TAB_WIDTH do
					table.insert(line, " ")
				end
			else
				table.insert(line, c)

				-- Capture position after inserting the char so #line reflects it.
				-- Add 1 to source_char_pos to match the increment below.
				if i == local_start then
					line_start = line_pos
					source_code_char_start = source_char_pos + 1
					char_start = #line
				end

				if i == local_stop then
					line_stop = line_pos
					source_code_char_stop = source_char_pos + 1
					char_stop = #line
				end
			end

			source_char_pos = source_char_pos + 1
		else
			-- Capture position for a newline BEFORE flushing the line buffer,
			-- otherwise #line would be 0 after the flush.
			if i == local_start then
				line_start = line_pos
				source_code_char_start = source_char_pos
				char_start = #line + 1
			end

			if i == local_stop then
				line_stop = line_pos
				source_code_char_stop = source_char_pos
				char_stop = #line
			end
		end

		if c == "\n" or i == #local_str then
			table.insert(lines, table.concat(line))
			line_pos = line_pos + 1
			line = {}
			source_char_pos = 0
		end
	end

	return {
		lines = lines,
		local_str = local_str,
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
		severity = nil | string, -- "error" | "warning" | "hint"
		level = nil | number, -- diagnostic level, shown in box header
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
	-- Metadata for color post-processing (unused when is_color is false)
	-- source_line_map[annotated_idx] = {line_idx, gutter_len}
	-- caret_line_set[annotated_idx]  = true
	local source_line_map = {}
	local caret_line_set = {}
	local box_bottom_idx = nil
	local right_border_set = {} -- ai → true when line needs a right │ border
	local inner_sep_set = {} -- ai → true for inner horizontal separator lines
	local footer_main_set = {} -- ai → true for the main error message line
	local footer_trace_set = {} -- ai → true for traceback / path lines
	local full_visual_width = 0 -- gutter_len + inner_width; set during box building
	-- this will be replaced later
	if config.show_box then table.insert(annotated, "") end

	for i, line in ipairs(d.lines) do
		local header = config.show_line_numbers == false and
			"" or
			" " .. stringx.pad_left(tostring(i + d.line_offset), number_length, " ") .. SEPARATOR

		if i == d.line_start and i == d.line_stop then
			-- only spans one line
			local before = line:sub(1, d.char_start - 1)
			local between = line:sub(d.char_start, d.char_stop)
			local after = line:sub(d.char_stop + 1, #line)

			if d.char_start > #line then between = between .. "\\n" end

			before, between, after = truncate_span(before, between, after)
			before = header .. before
			table.insert(annotated, before .. between .. after)
			source_line_map[#annotated] = {line_idx = i, gutter_len = #header}
			table.insert(annotated, (" "):rep(#before) .. ("^"):rep(#between))
			caret_line_set[#annotated] = true
		elseif i == d.line_start then
			-- multiple line span, first line
			local before = line:sub(1, d.char_start - 1)
			local after = line:sub(d.char_start, #line)

			-- newline
			if d.char_start > #line then after = "\\n" end

			before = header .. before
			table.insert(annotated, before .. after)
			source_line_map[#annotated] = {line_idx = i, gutter_len = #header}
			table.insert(annotated, (" "):rep(#before) .. ("^"):rep(#after))
			caret_line_set[#annotated] = true
		elseif i == d.line_stop then
			-- multiple line span, last line
			local before = line:sub(1, d.char_stop)
			local after = line:sub(d.char_stop + 1, #line)
			table.insert(annotated, header .. before .. after)
			source_line_map[#annotated] = {line_idx = i, gutter_len = #header}
			table.insert(annotated, (" "):rep(#header) .. ("^"):rep(#before))
			caret_line_set[#annotated] = true
		elseif i > d.line_start and i < d.line_stop then
			-- multiple line span, in between start and stop lines
			local after = line
			table.insert(annotated, header .. after)
			source_line_map[#annotated] = {line_idx = i, gutter_len = #header}
			table.insert(annotated, (" "):rep(#header) .. ("^"):rep(#after))
			caret_line_set[#annotated] = true
		else
			table.insert(annotated, header .. line)
			source_line_map[#annotated] = {line_idx = i, gutter_len = #header}
		end
	end

	local header = config.show_line_numbers == false and
		"" or
		" " .. stringx.pad_left(ARROW, number_length, " ") .. SEPARATOR
	local plain_header = config.show_line_numbers == false and
		"" or
		"  " .. (
			" "
		):rep(number_length) .. SEPARATOR

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

	-- Collect footer items.
	-- config.path → trace entry; messages: last → main error, rest → trace.
	local footer_items = {}

	if config.path then
		local path = config.path

		if path:sub(1, 1) == "@" then path = path:sub(2) end

		local msg = path .. ":" .. (d.line_start + d.line_offset) .. ":" .. d.source_code_char_start
		table.insert(footer_items, {text = plain_header .. msg, kind = "trace"})
	end

	if config.messages then
		for i, msg in ipairs(config.messages) do
			local kind = (i == #config.messages) and "main" or "trace"
			local pfx = kind == "main" and header or plain_header
			-- Split multi-line messages: prefix goes on the first line only;
			-- continuation lines get a plain indent equal to the prefix width.
			local cont_pfx = (" "):rep(#pfx)
			local first = true

			for line in (msg .. "\n"):gmatch("([^\n]*)\n") do
				local p = first and pfx or cont_pfx
				table.insert(footer_items, {text = p .. line, kind = kind})
				first = false
			end
		end
	end

	if config.show_box then
		-- Compute inner_width from all content (source lines, carets, footer items).
		-- annotated[1] is the box-top placeholder (empty ""), skip it.
		local longest_line = 0

		for i = 2, #annotated do
			if #annotated[i] > longest_line then longest_line = #annotated[i] end
		end

		for _, item in ipairs(footer_items) do
			if #item.text > longest_line then longest_line = #item.text end
		end

		local gutter_len = number_length + #SEPARATOR
		-- inner_width: visual content cols between gutter and right │ border
		local inner_width = math.max(longest_line - gutter_len, 4)
		-- full_visual_width: gutter + content (right border adds 2 more visual cols)
		full_visual_width = gutter_len + inner_width

		-- Mark all current source/caret lines as needing a right border
		for i = 2, #annotated do
			right_border_set[i] = true
		end

		-- Inner separator: "=" markers replaced by "─" in post-processing
		local sep = (" "):rep(gutter_len) .. ("="):rep(inner_width + 2)
		local has_main, has_trace = false, false

		for _, item in ipairs(footer_items) do
			if item.kind == "main" then has_main = true else has_trace = true end
		end

		-- Main error → inside box, between two separators
		if has_main then
			table.insert(annotated, sep)
			inner_sep_set[#annotated] = true

			for _, item in ipairs(footer_items) do
				if item.kind == "main" then
					table.insert(annotated, item.text)
					footer_main_set[#annotated] = true
					right_border_set[#annotated] = true
				end
			end
		end

		-- Trace/path items → after second separator
		if has_trace then
			table.insert(annotated, sep)
			inner_sep_set[#annotated] = true

			for _, item in ipairs(footer_items) do
				if item.kind == "trace" then
					table.insert(annotated, item.text)
					footer_trace_set[#annotated] = true
					right_border_set[#annotated] = true
				end
			end
		end

		-- Box top ("_" markers) and box bottom ("-" markers)
		annotated[1] = (" "):rep(gutter_len) .. ("_"):rep(inner_width + 2)
		table.insert(annotated, (" "):rep(gutter_len) .. ("-"):rep(inner_width + 2))
		box_bottom_idx = #annotated
	else
		-- No box: append footer lines directly without borders
		for _, item in ipairs(footer_items) do
			table.insert(annotated, item.text)

			if item.kind == "main" then
				footer_main_set[#annotated] = true
			else
				footer_trace_set[#annotated] = true
			end
		end
	end

	-- ── Color + Unicode post-processing ──────────────────────────────────────
	if is_color and not is_markdown and not is_plain then
		local sev_color = ansi.severity_color(config.severity--[[# as any]])
		local border_color = sev_color
		local spans = get_highlight_spans(d.local_str)
		local colored_lines = build_colored_lines(d.local_str, spans)

		for ai = 1, #annotated do
			local entry = annotated[ai]
			local src = source_line_map[ai]
			local has_border = right_border_set[ai]

			if src then
				-- Source line: replace content after gutter with colored version.
				local gl = src.gutter_len
				local colored = colored_lines[src.line_idx] or entry:sub(gl + 1)
				local li = src.line_idx
				local padding = has_border and math.max(0, full_visual_width - gl - (#entry - gl)) or 0
				local border = has_border and (border_color .. " │" .. ansi.reset) or ""
				-- Split gutter into line-number part + separator for per-part coloring
				local num_part = entry:sub(1, gl - #SEPARATOR)

				if li >= d.line_start and li <= d.line_stop then
					-- Highlighted line: dim line number, color the │, syntax-color content
					local gutter = ansi.dim .. num_part .. ansi.reset .. border_color .. " │ " .. ansi.reset
					annotated[ai] = gutter .. colored .. (" "):rep(padding) .. border
				else
					-- Context line: dim everything
					local gutter = entry:sub(1, gl):gsub(" | $", " │ ")
					annotated[ai] = ansi.dim .. gutter .. colored .. ansi.reset .. (" "):rep(padding) .. border
				end
			elseif caret_line_set[ai] then
				-- Caret line: color "^^^" with severity color
				local spaces, carets = entry:match("^( *)(%^+)")

				if spaces and carets then
					local padding = has_border and math.max(0, full_visual_width - #spaces - #carets) or 0
					local border = has_border and (border_color .. " │" .. ansi.reset) or ""
					annotated[ai] = spaces .. sev_color .. carets .. ansi.reset .. (" "):rep(padding) .. border
				end
			elseif inner_sep_set[ai] then
				-- Inner separator: "===..." → "───..." in border color
				local prefix = entry:match("^( *)")
				local n = #entry - #prefix
				annotated[ai] = border_color .. prefix .. ("─"):rep(n) .. ansi.reset
			elseif footer_main_set[ai] then
				-- Main error: bold + severity color
				local gl = 1 + number_length + #SEPARATOR
				local gutter = entry:sub(1, gl):gsub("%->", "→ "):gsub(" | $", " │ ")
				local text = entry:sub(gl + 1)
				local padding = has_border and math.max(0, full_visual_width - gl - #text) or 0
				local border = has_border and (border_color .. " │" .. ansi.reset) or ""
				annotated[ai] = sev_color .. ansi.bold .. gutter .. text .. ansi.reset .. (
						" "
					):rep(padding) .. border
			elseif footer_trace_set[ai] then
				-- Trace/path line: dim
				local gl = 2 + number_length + #SEPARATOR
				local gutter = entry:sub(1, gl):gsub("%->", "→ "):gsub(" | $", " │ ")
				local text = entry:sub(gl + 1)
				local padding = has_border and math.max(0, full_visual_width - gl - #text) or 0
				local border = has_border and (border_color .. " │" .. ansi.reset) or ""
				annotated[ai] = ansi.dim .. gutter .. text .. ansi.reset .. (" "):rep(padding) .. border
			elseif config.show_box and ai == 1 then
				-- Box top: "____..." → ╭ severity_label ────╮
				local prefix = entry:match("^( *)")
				local rest = entry:sub(#prefix + 1)
				local n = #rest

				if n >= 2 then
					local sev = config.severity--[[# as any]]
					local lv = config.level--[[# as any]]
					local label = ""

					if sev and sev ~= "" then
						label = sev

						if lv then label = label .. " (lvl." .. tostring(lv) .. ")" end

						label = " " .. label .. " "
					end

					local bar_len = math.max(0, n - 2 - #label)
					local left_border = prefix .. "╭"
					local right_border = ("─"):rep(bar_len) .. "╮"

					if label ~= "" then
						annotated[ai] = border_color .. left_border .. ansi.bold .. label .. ansi.reset .. border_color .. right_border .. ansi.reset
					else
						annotated[ai] = border_color .. left_border .. right_border .. ansi.reset
					end
				end
			elseif box_bottom_idx and ai == box_bottom_idx then
				-- Box bottom: "---..." → ╰────╯
				local prefix = entry:match("^( *)")
				local n = #entry - #prefix

				if n >= 2 then
					annotated[ai] = border_color .. prefix .. "╰" .. ("─"):rep(n - 2) .. "╯" .. ansi.reset
				end
			end
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
