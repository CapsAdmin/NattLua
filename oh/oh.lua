local oh = {}

oh.syntax = assert(loadfile("oh/syntax.lua"))(oh)
assert(loadfile("oh/tokenizer.lua"))(oh)
assert(loadfile("oh/parser.lua"))(oh)
assert(loadfile("oh/analyzer.lua"))(oh)
assert(loadfile("oh/lua_emitter.lua"))(oh)

local util = require("oh.util")

function oh.ASTToCode(ast, config)
    local self = oh.LuaEmitter(config)
    return self:BuildCode(ast)
end

local function on_error(self, msg, start, stop)
    self.errors = self.errors or {}
    table.insert(self.errors, {msg = msg, start = start, stop = stop})
end

function oh.CodeToTokens(code, name)
	name = name or "unknown"

	local tokenizer = oh.Tokenizer(code)
    tokenizer.OnError = on_error
    local tokens = tokenizer:GetTokens()
    if tokenizer.errors then
        local str = ""
        for _, err in ipairs(tokenizer.errors) do
            str = str .. oh.FormatError(code, name, err.msg, err.start, err.stop) .. "\n"
        end
        return nil, str
	end

	return tokens, tokenizer
end

local function on_error(self, msg, start, stop)
    self.errors = self.errors or {}
	table.insert(self.errors, {msg = msg, start = start, stop = stop})
	error(msg)
end

function oh.TokensToAST(tokens, name, code, config)
	name = name or "unknown"

	local parser = oh.Parser(config)
    parser.OnError = on_error
    local ok, ast = pcall(parser.BuildAST, parser, tokens)
	if not ok then
		if parser.errors then
			local str = ""
			for _, err in ipairs(parser.errors) do
				if code then
					str = str .. oh.FormatError(code, name, err.msg, err.start, err.stop) .. "\n"
				else
					str = str .. err.msg .. "\n"
				end
			end
			return nil, str
		else
			return nil, ast
		end
	end

	return ast, parser
end

function oh.Transpile(code, name, config)
    name = name or "unknown"

	local tokens, err = oh.CodeToTokens(code, name)
	if not tokens then return nil, err end

	local ast, err = oh.TokensToAST(tokens, name, code, config)
	if not ast then return nil, err end
	return oh.ASTToCode(ast, config)
end

function oh.loadstring(code, name, config)
	local code, err = oh.Transpile(code, name, config)
	if not code then return nil, err end

    return loadstring(code, name)
end


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

local function count(tbl, what, stop)
    local found = 0
	--for i, v in ipairs(tbl) do
	for i = 1, #tbl do
		local v = tbl:sub(i, i)
		if v == "\n" then
			found = found + 1
		end
		if stop and i >= stop then
			break
		end
	end
    return found
end

local function sub(tbl, start, stop)
	local out = {}
	for i = start, stop do
		table.insert(out, tbl[i])
	end
	return table.concat(out)
end

do
	local function sub_pos_2_line_pos(code, start, stop)
		local line = 1

		local line_start
		local line_stop

		local within_start
		local within_stop

		local line_pos = 0

		for i = 1, #code do
			local char = code:sub(i, i)


			if i == stop then
				line_stop = line
			end

			if i == start then
				line_start = line
				within_start = line_pos
			end

			if char == "\n" then
				if line_stop then
					within_stop = i
					break
				end

				line = line + 1
				line_pos = i
			end
		end

		if not within_stop then
			within_stop = #code + 1
		end

		if not within_start then
			return
		end

		return {
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
					first_line_pos = i
				end

				line = line + 1

				if line == lines + 2 then
					return i + 1, first_line_pos - 1, line
				end
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

	local function get_current_line(code, start, stop)
		local line_start
		local line_stop

		for i = start, 1, -1 do
			local char = code:sub(i, i)
			if char == "\n" then
				line_start = i
				break
			end
		end

		for i = stop, #code do
			local char = code:sub(i, i)
			if char == "\n" then
				line_stop = i
				break
			end
		end

		return line_start + 1, line_stop-1
	end

	function oh.FormatError(code, path, msg, start, stop)
		local data = sub_pos_2_line_pos(code, start, stop)

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
				local line = line_start - lines_before + 1
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
						prefix = prefix .. code:sub(unpack(data.sub_line_before))
					end

					local test = str

					if line == line_stop then
						str = str .. code:sub(unpack(data.sub_line_after))
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

		local path = path .. ":" .. line_start
		local msg = path .. (msg and ": " .. msg or "")
		local post = (" "):rep(spacing - 2) .. "-> | " .. msg

		local pre = ("="):rep(#post)

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

return oh