local coverage = {}
_G.__COVERAGE = _G.__COVERAGE or {}
coverage.collected = {}

function coverage.Preprocess(code, key)
	local nl = require("nattlua")
	local expressions = {}

	local function inject_call_expression(parser, node, start, stop)
		local call_expression = parser:ParseString(" Æ(" .. start .. "," .. stop .. ") ").statements[1].value

		-- add comma to last expression since we're adding a new one
		call_expression.expressions[#call_expression.expressions].tokens[","] = parser:NewToken("symbol", ",")
		table.insert(call_expression.expressions, node)

		if node.right then call_expression.right = node.right end

		table.insert(expressions, node)

		return call_expression
	end
 
	local compiler = nl.Compiler(
		code,
		"lol",
		{
			on_node = function(parser, node)
				if node.type == "statement" then
					if node.kind == "call_expression" then
						local start, stop = node:GetStartStop()
						node.value = inject_call_expression(parser, node.value, start, stop)
					end
				elseif node.type == "expression" then
					local start, stop = node:GetStartStop()

					if node.is_left_assignment or node.is_identifier or 
						(node.kind == "binary_operator" and (node.value.value == "." or node.value.value == ":")) or
						(node.parent.kind == "binary_operator" and (node.parent.value.value == "." or node.parent.value.value == ":"))
					then
						return
					end

					return inject_call_expression(parser, node, start, stop)
				end
			end,
			skip_import = true,
		}
	)
	assert(compiler:Parse())
	local lua = compiler:Emit()
	lua = [[
local called = _G.__COVERAGE["]] .. key .. [["].called
local function Æ(start, stop, ...)
	called[start..", "..stop] = {start, stop}
	return ...
end
------------------------------------------------------
]] .. lua
	_G.__COVERAGE[key] = _G.__COVERAGE[key] or {called = {}, expressions = expressions, compiler = compiler, preprocesed = lua}

	return lua
end

function coverage.GetAll()
	return _G.__COVERAGE
end

local MASK = " "

function coverage.Collect(key)
    local data = _G.__COVERAGE[key]

	local called = data.called
	local expressions = data.expressions
	local compiler = data.compiler

	local original = compiler.Code:GetString()
	local buffer = {}
	for i = 1, #original do
		buffer[i] = original:sub(i, i)
	end

	local not_called = {}

	for _, exp in ipairs(expressions) do
		local start, stop = exp:GetStartStop()
		if not called[start..", "..stop] then
			for i = start, stop do
				not_called[i] = true
			end
		end
	end

	local function mask_token(token)
		for i = token.start, token.stop do
			if buffer[i] ~= MASK and buffer[i] ~= "\n" then
				buffer[i] = MASK
			end
		end
	end

	local function mask_node(node)
		local start, stop = node:GetStartStop()

		for i = start, stop do
			if buffer[i] ~= MASK and buffer[i] ~= "\n" then
				buffer[i] = MASK
			end
		end		
	end


	local function mask_tokens(tokens)
		for _, token in pairs(tokens) do
			if not token.start then
				for _, token in ipairs(token) do
					mask_token(token)
				end
			else
				mask_token(token)
			end
		end
	end

	for _, exp in ipairs(expressions) do
		local start, stop = exp:GetStartStop()
		local key = start..", "..stop
		if called[key] then
			local statement = exp:GetStatement()
			if statement.kind == "local_assignment" then
				for _, node in ipairs(statement.left) do
					mask_node(node)
				end
			elseif statement.kind == "numeric_for" then
				for _, node in ipairs(statement.identifiers) do
					mask_node(node)
				end
				for _, node in ipairs(statement.expressions) do
					mask_tokens(node.tokens)
				end
			end

			mask_tokens(statement.tokens)
			
			if exp.kind == "table" then
				for _, statement in ipairs(exp.children) do
					mask_tokens(statement.tokens)
				end
			elseif exp.kind == "binary_operator" then
				mask_token(exp.value)
			end
			mask_tokens(exp.tokens)
		end
	end

	for _, start_stop in pairs(called) do
		local start, stop = unpack(start_stop)

		for i = start, stop do
			if not not_called[i] then
				if buffer[i] ~= MASK and buffer[i] ~= "\n" then
					buffer[i] = MASK
				end
			end
		end
	end

	return table.concat(buffer)
end

return coverage
