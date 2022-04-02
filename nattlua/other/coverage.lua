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
					expressions[start .. "," .. stop] = {start, stop}

					if node.is_left_assignment or node.is_identifier or 
						(node.kind == "binary_operator" and (node.value.value == "." or node.value.value == ":")) or
						(node.parent.kind == "binary_operator" and (node.parent.value.value == "." or node.parent.value.value == ":"))
					then
						return
					end

					expressions[start .. "," .. stop] = {start, stop}

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

function coverage.Collect(key)
	local called = _G.__COVERAGE[key].called
	local expressions = _G.__COVERAGE[key].expressions
	local compiler = _G.__COVERAGE[key].compiler


	local original = compiler.Code:GetString()
	local buffer = {}
	for i = 1, #original do
		buffer[i] = original:sub(i, i)
	end
	
	-- remove sub calls
	for key1, start_stop in pairs(called) do
		local start, stop = unpack(start_stop)
		for key2, start_stop2 in pairs(called) do
			local start2, stop2 = unpack(start_stop2)

			if start2 > start and stop2 < stop then
				called[key1] = nil
			end
		end
	end

	for _, start_stop in pairs(called) do
		local start, stop = unpack(start_stop)

		print(start, stop)

		for i = start, stop do
			buffer[i] = "#"
		end
	end

	print(table.concat(buffer))
end

return coverage
