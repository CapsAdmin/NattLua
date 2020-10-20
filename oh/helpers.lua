local helpers = {}

function helpers.QuoteToken(str)
	return "❲" .. str .. "❳"
end

function helpers.QuoteTokens(var--[[#: {[number] = string}]])
	local str = ""
	for i, v in ipairs(var) do
		str = str .. helpers.QuoteToken(v)

		if i == #var - 1 then
			str = str .. " or "
		elseif i ~= #var then
			str = str .. ", "
		end
	end
	return str
end

function helpers.LinePositionToSubPosition(code, line, character)
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

				char_pos = char_pos + 1
			end

			return i
		end

		if c == "\n" then
			line_pos = line_pos + 1
		end
	end

	return #code
end

function helpers.SubPositionToLinePosition(code--[[#: string]], start--[[#: number]], stop--[[#: number]])
	assert(type(code) == "string")
	assert(type(start) == "number")
	assert(type(stop) == "number")
	
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
			char_pos = char_pos + 1
		end
	end

	if not within_stop then
		within_stop = #code + 1
	end

	if not within_start then
		return
	end

	return {
		character_start = character_start or 0,
		character_stop = character_stop or 0,
		sub_line_before = {within_start + 1, start - 1},
		sub_line_after = {stop + 1, within_stop - 1},
		line_start = line_start or 0,
		line_stop = line_stop or 0,
	}
end

do
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
		-- TODO: wtf am i doing here?
		local args
		local fmt = function(num)
			num = tonumber(num)
			if type(args[num]) == "table" then
				return helpers.QuoteTokens(args[num] --[[# as {[number] = string}]])
			end
			return helpers.QuoteToken(args[num] or "?")
		end
		function helpers.FormatMessage(msg--[[#:string]], ...)
			args = {...}--[[# as {[number] = string}]]
			msg = msg:gsub("$(%d)", fmt)

			return msg
		end
	end

	local function clamp(num, min, max) return math.min(math.max(num, min), max) end

	function helpers.FormatError(code--[[#: string]], path--[[#: string]], msg--[[#: string]], start--[[#:number]], stop--[[#: number]], size--[[#: number]], ...)
		size = size or 2
		msg = helpers.FormatMessage(msg, ...)

		start = clamp(start, 1, #code)
		stop = clamp(stop, 1, #code)

		local data = helpers.SubPositionToLinePosition(code, start, stop)

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

		local pre_start_pos, pre_stop_pos, lines_before = get_lines_before(code, start, size, line_start)
		local post_start_pos, post_stop_pos, lines_after = get_lines_after(code, stop, size, line_stop)

		local spacing = #tostring(data.line_stop + lines_after)
		local lines = {}

		do
			if lines_before >= 0 then
				local line = math.max(line_start - lines_before- 1, 1)
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
						prefix = prefix .. code:sub(table.unpack(data.sub_line_before))
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

		local pre = ("-"):rep(100)

		str = "\n" .. pre .. "\n" .. str .. "\n" .. pre .. "\n" .. post .. "\n"

		str = str:gsub("\t", " ")

		return str
	end
end


do
	local blacklist = {
		parent = true,
		inferred_type = true,
		scope = true,
		parser = true,
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

	function helpers.LazyFindStartStop(tbl)
		if tbl.start and tbl.stop then
			return tbl.start, tbl.stop
		end
        local out = {min = -math.huge, max = math.huge}
		traverse(tbl, {}, out)
        return out.max, out.min
    end
end

function helpers.GetDataFromLineCharPosition(tokens, code, line, char)
	local sub_pos = helpers.LinePositionToSubPosition(code, line, char)

	for _, token in ipairs(tokens) do
		local found = token.stop >= sub_pos-- and token.stop <= sub_pos

		if not found and token.whitespace then
			for _, token in ipairs(token.whitespace) do
				if token.stop >= sub_pos--[[ and token.stop <= sub_pos]] then
					found = true
					break
				end
			end
		end

		if found then
			return token, helpers.SubPositionToLinePosition(code, token.start, token.stop)
		end
	end
end

return helpers