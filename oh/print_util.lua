local oh = {}

function oh.QuoteToken(str)
	return "❲" .. str .. "❳"
end

function oh.QuoteTokens(var)
	local str = ""
	for i, v in ipairs(var) do
		str = str .. oh.QuoteToken(v)

		if i == #var - 1 then
			str = str .. " or "
		elseif i ~= #var then
			str = str .. ", "
		end
	end
	return str
end

local tab_size = 1

do
	function oh.LinePositionToSubPosition(code, line, character)
		local line_pos = 1
		for i = 1, #code do
			local c = code:sub(i, i)

			if line_pos == line then
				local char_pos = 1

				for i = i, i + character do
					local c = code:sub(i, i)

					if char_pos == character then
						return i
					end

					if c == "\t" then
						char_pos = char_pos +tab_size
					else
						char_pos = char_pos + 1
					end
				end

				return i
			end

			if c == "\n" then
				line_pos = line_pos + 1
			end
		end

		return #code
	end

	function oh.SubPositionToLinePosition(code, start, stop)
		local line = 1

		local line_start
		local line_stop

		local within_start
		local within_stop

		local character_start
		local character_stop

		local line_pos = 0
		local char_pos = 0

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
				char_pos = 0
			else
				if char == "\t" then
					char_pos = char_pos + tab_size
				else
					char_pos = char_pos + 1
				end
			end
		end

		if not within_stop then
			within_stop = #code + 1
		end

		if not within_start then
			return
		end

		return {
			character_start = character_start,
			character_stop = character_stop,
			sub_line_before = {within_start + 1, start - 1},
			sub_line_after = {stop + 1, within_stop - 1},
			line_start = line_start,
			line_stop = line_stop,
		}
	end

	local function get_lines_before(code, pos, lines)
		local line = 1
		local first_line_pos = 1

		for i = pos, 1, -1 do
			local char = code:sub(i, i)
			if char == "\n" then
				if line == 1 then
					first_line_pos = i+1
				end

				if line == lines+1 then
					return i-1, first_line_pos-1, line
				end

				line = line + 1
			end
		end

		return 1, first_line_pos, line
	end

	local function get_lines_after(code, pos, lines)
		local line = 1
		local first_line_pos = 1

		for i = pos, #code do
			local char = code:sub(i, i)
			if char == "\n" then
				if line == 1 then
					first_line_pos = i
				end

				if line == lines + 1 then
					return first_line_pos + 1, i - 1, line
				end

				line = line + 1
			end
		end

		return first_line_pos + 1, #code, line-1
	end

	do
		local args
		local fmt = function(num)
			num = tonumber(num)
			if type(args[num]) == "table" then
				return oh.QuoteTokens(args[num])
			end
			return oh.QuoteToken(args[num] or "?")
		end
		function oh.FormatMessage(msg, ...)
			args = {...}
			msg = msg:gsub("$(%d)", fmt)

			return msg
		end
	end

	local function clamp(num, min, max) return math.min(math.max(num, min), max) end

	function oh.FormatError(code, path, msg, start, stop, ...)
		msg = oh.FormatMessage(msg, ...)

		start = clamp(start, 1, #code)
		stop = clamp(stop, 1, #code)

		local data = oh.SubPositionToLinePosition(code, start, stop)

		if not data then
			local str = ""
			if path then
				str = str .. path .. ":INVALID: "
			end

			if msg then
				str = str .. msg
			end
			return str
		end

		local line_start, line_stop = data.line_start, data.line_stop

		local pre_start_pos, pre_stop_pos, lines_before = get_lines_before(code, start, 5, line_start)
		local post_start_pos, post_stop_pos, lines_after = get_lines_after(code, stop, 5, line_stop)

		local spacing = #tostring(data.line_stop + lines_after)
		local lines = {}

		do
			if lines_before > 0 then
				local line = line_start - lines_before - 1
				for str in (code:sub(pre_start_pos, pre_stop_pos)):gmatch("(.-)\n") do
					local prefix = (" "):rep(spacing - #tostring(line)) .. line .. " | "
					table.insert(lines, prefix .. str)
					line = line + 1
				end
			end

			do
				local line = line_start
				for str in (code:sub(start, stop) .. "\n"):gmatch("(.-)\n") do
					local prefix = (" "):rep(spacing - #tostring(line)) .. line .. " | "

					if line == line_start then
						prefix = prefix .. code:sub(table.unpack(data.sub_line_before)):gsub("\t", (" "):rep(tab_size))
					end

					local test = str

					if line == line_stop then
						str = str .. code:sub(table.unpack(data.sub_line_after))
					end

					str = str .. "\n" .. (" "):rep(#prefix) .. ("^"):rep(math.max(#test, 1))

					table.insert(lines, prefix .. str)
					line = line + 1
				end
			end

			if lines_after > 0 then
				local line = line_stop + 1
				for str in (code:sub(post_start_pos, post_stop_pos) .. "\n"):gmatch("(.-)\n") do
					local prefix = (" "):rep(spacing - #tostring(line)) .. line .. " | "
					table.insert(lines, prefix .. str)
					line = line + 1
				end
			end

		end

		local str = table.concat(lines, "\n")

		local path = path and (path:gsub("@", "") .. ":" .. line_start  .. ":".. data.character_start) or ""
		local msg = path .. (msg and ": " .. msg or "")
		local post = (" "):rep(spacing - 2) .. "-> | " .. msg

		local pre = ("="):rep(100)

		str = pre .. "\n" .. str .. "\n" .. pre .. "\n" .. post .. "\n" .. pre

		return str
	end
end

function oh.GetErrorsFormatted(error_table, code, path)
	if not error_table[1] then
		return ""
	end

	local errors = {}
	local max_width = 0

	for i, data in ipairs(error_table) do
		local msg = oh.FormatError(code, path, data.msg, data.start, data.stop)

		for _, line in ipairs(msg:split("\n")) do
			max_width = math.max(max_width, #line)
		end

		errors[i] = msg
	end

	local str = ""

	for _, msg in ipairs(errors) do
		str = str .. ("="):rep(max_width) .. "\n" .. msg .. "\n"
	end

	str = str .. ("="):rep(max_width) .. "\n"

	return str
end

do
	local blacklist = {
		inferred_type = true,
		scope = true,
	}
    local function traverse(tbl, done, out)
		for k, v in pairs(tbl) do
			if not blacklist[k] then
				if type(v) == "table" and not done[v] then
					done[v] = true
					traverse(v, done, out)
				end
				if type(v) == "number" then
					if tbl.type ~= "space" then
						if k == "start" then
							out.max = math.min(out.max, v)
						elseif k == "stop" then
							out.min = math.max(out.min, v)
						end
					end
				end
			end
        end
    end

	function oh.LazyFindStartStop(tbl)
		if tbl.start and tbl.stop then
			return tbl.start, tbl.stop
		end
        local out = {min = -math.huge, max = math.huge}
		traverse(tbl, {}, out)
        return out.max, out.min
    end
end

return oh