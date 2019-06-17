local oh = {}

oh.syntax = assert(loadfile("oh/syntax.lua"))(oh)
assert(loadfile("oh/tokenizer.lua"))(oh)
assert(loadfile("oh/parser.lua"))(oh)
assert(loadfile("oh/lua_emitter.lua"))(oh)

function oh.ASTToCode(ast, config)
    local self = oh.LuaEmitter(config)
    return self:BuildCode(ast)
end

local function on_error(self, msg, start, stop)
    self.errors = self.errors or {}
    table.insert(self.errors, {msg = msg, start = start, stop = stop})
end

function oh.CodeToAST(code, name)
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

    local parser = oh.Parser()
    parser.OnError = on_error
    local ast = parser:BuildAST(tokens)
    if parser.errors then
        local str = ""
        for _, err in ipairs(parser.errors) do
            str = str .. oh.FormatError(code, name, err.msg, err.start, err.stop) .. "\n"
        end
        return nil, str
    end

    return ast, tokens
end

function oh.loadstring(code, name)
    local ast, err = oh.CodeToAST(code, name)

    if not ast then return nil, err end

    code = oh.ASTToCode(ast)

    local func, err = loadstring(code, name)

    print(code)
    if not func then
        return nil, err
    end

    return func
end


function oh.QuoteToken(str)
	return "⸢" .. str .. "⸥"
end

function oh.QuoteTokens(var)
	if type(var) == "string" then
        local temp = {}
        for i = 1, #var do
            temp[i] = var:sub(i,i)
        end
        var = temp
	end

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

local function count(str, what)
    local found = 0
    for i = 1, #str do
        if str:sub(i, i + #what - 1) == what then
            found = found + 1
        end
    end
    return found
end

function oh.FormatError(code, path, msg, start, stop)
	local total_lines = count(code, "\n")
	local line_number_length = #tostring(total_lines)

	local function tab2space(str)
		return str:gsub("\t", "    ")
	end

	local function line2str(i)
		return ("%i%s"):format(i, (" "):rep(line_number_length - #tostring(i)))
	end

	local context_size = 100
	local line_context_size = 1

	local length = (stop - start) + 1
	local before = code:sub(math.max(start - context_size, 0), stop - length)
	local middle = code:sub(start, stop)
	local after = code:sub(stop + 1, stop + context_size)

	local context_before, line_before = before:match("(.+\n)(.*)")
	local line_after, context_after = after:match("(.-)(\n.+)")

	if not line_before then
		context_before = before
		line_before = before
	end

	if not line_after then
		context_after = after
		line_after = after

		-- hmm
		if context_after == line_after then
			context_after = ""
		end
	end

	local current_line = count(code:sub(0, stop), "\n") + 1
	local char_number = #line_before + 1

	line_before = tab2space(line_before)
	line_after = tab2space(line_after)
	middle = tab2space(middle)

	local out = ""
	out = out .. "error: " ..  msg .. "\n"
	out = out .. " " .. ("-"):rep(line_number_length + 1) .. "> " .. path .. ":" .. current_line .. ":" .. char_number .. "\n"

	if line_context_size > 0 then
        local lines = {}
        for line in tab2space(context_before:sub(0, -2)):gmatch("(.-)\n") do
            table.insert(lines, line)
        end

		if #lines ~= 1 or lines[1] ~= "" then
			for offset = math.max(#lines - line_context_size, 1), #lines do
				local str = lines[offset]
				--if str:trim() ~= "" then
					offset = offset - 1
					local line = current_line - (-offset + #lines)
					if line ~= 0 then
						out = out .. line2str(line) .. " | " .. str .. "\n"
					end
				--end
			end
		end
	end

	out = out .. line2str(current_line) .. " | " .. line_before .. middle .. line_after .. "\n"
	out = out .. (" "):rep(line_number_length) .. " |" .. (" "):rep(#line_before + 1) .. ("^"):rep(length) .. " " .. msg .. "\n"

	if line_context_size > 0 then
        local lines = {}
        for line in tab2space(context_after:sub(2)):gmatch("(.-)\n") do
            table.insert(lines, line)
        end
		if #lines ~= 1 or lines[1] ~= "" then
			for offset = 1, #lines do
				local str = lines[offset]
				--if str:trim() ~= "" then
					out = out .. line2str(current_line + offset) .. " | " .. str .. "\n"
				--end
				if offset >= line_context_size then break end
			end
		end
	end

	return out
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