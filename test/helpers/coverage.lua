--[[HOTRELOAD
	run_test("test/tests/coverage.lua")
]]

local coverage = {}
_G.__COVERAGE = _G.__COVERAGE or {}
coverage.collected = {}
local nl = require("nattlua")
local FUNC_NAME = "__CLCT"
local loadstring = loadstring or load

function coverage.Preprocess(code, key)
	local expressions = {}

	local function inject_call_expression(parser, node, start, stop)
		if node.environment == "typesystem" then return node end

		if node.Type == "expression_postfix_call" and node.type_call then return node end

		if node.Type == "expression_function" then
			-- don't mark the funciton body as being called
			start, stop = node.tokens["function"].start, node.tokens["function"].stop
		end

		if node.Type == "expression_table" then
			-- don't mark the funciton body as being called
			start, stop = node.tokens["{"].start, node.tokens["{"].stop
		end

		local call_expression = parser:ParseString(" " .. FUNC_NAME .. "(" .. start .. "," .. stop .. ",x)").statements[1].value

		if node.Type == "expression_postfix_call" and not node.tokens["call("] then
			node.tokens["call("] = parser:NewToken("symbol", "(")
			node.tokens["call)"] = parser:NewToken("symbol", ")")
		end

		call_expression.expressions[3] = node

		if node.Type == "expression_binary_operator" and node.right then
			call_expression.right = node.right
		end

		table.insert(expressions, node)
		-- to prevent start stop messing up from previous injections
		call_expression.code_start = node.code_start
		call_expression.code_stop = node.code_stop
		return call_expression
	end

	local function inject_token(token)
		token.value = " " .. FUNC_NAME .. "(" .. token.start .. "," .. token.stop .. ",x) " .. token.value
	end

	local compiler = nl.Compiler(
		code,
		key,
		{
			parser = {
				on_parsed_node = function(parser, node)
					if node.is_statement then
						-- inject a call right before the token itself which uses the token for range
						if node.Type == "statement_return" then
							inject_token(node.tokens["return"])
						elseif node.Type == "statement_break" then
							inject_token(node.tokens["break"])
						elseif node.Type == "statement_continue" then
							inject_token(node.tokens["continue"])
						elseif node.Type == "statement_call_expression" then
							local start, stop = node:GetStartStop()
							node.value = inject_call_expression(parser, node.value, start, stop)
						end
					elseif node.is_expression then
						local start, stop = node:GetStartStop()

						if
							node.is_left_assignment or
							node.is_identifier or
							(
								node:GetStatement().Type == "statement_function" or
								node:GetStatement().Type == "statement_type_function"
							)
							or
							(
								node.Type == "expression_binary_operator" and
								node.value.value == ":"
							)
							or
							(
								node.parent and
								node.parent.Type == "expression_binary_operator" and
								(
									node.parent.value.value == "." or
									node.parent.value.value == ":"
								)
							)
						then
							return
						end

						return inject_call_expression(parser, node, start, stop)
					end
				end,
				skip_import = true,
			},
		}
	)
	assert(compiler:Parse())
	local lua = [[local called = _G.__COVERAGE["]] .. key .. [["].called;]]
	lua = lua .. [[local function ]] .. FUNC_NAME .. [[(start, stop, ...) ]]
	lua = lua .. [[local key = start..", "..stop;]]
	lua = lua .. [[called[key] = called[key] or {start, stop, 0};]]
	lua = lua .. [[called[key][3] = called[key][3] + 1;]]
	lua = lua .. [[return ...;]]
	lua = lua .. [[end; ]]
	local gen = compiler:Emit()
	lua = lua .. gen

	if not loadstring(gen) then
		local diff = require("nattlua.other.diff")
		local old = code
		local new = gen
		assert(diff.assert_equal(old, new))
	end

	_G.__COVERAGE[key] = _G.__COVERAGE[key] or
		{called = {}, expressions = expressions, compiler = compiler, preprocesed = lua}
	return lua
end

function coverage.GetAll()
	return _G.__COVERAGE
end

function coverage.Clear(key)
	_G.__COVERAGE[key] = nil
end

local function normalizeRanges(ranges)
	local map = {}
	local minVal = math.huge
	local maxVal = -math.huge

	for _, range in ipairs(ranges) do
		local start, finish, count = range[1], range[2], range[3]
		minVal = math.min(minVal, start)
		maxVal = math.max(maxVal, finish)

		for i = start, finish do
			map[i] = count
		end
	end

	local result = {}
	local currentStart = minVal
	local currentCount = map[minVal] or 0

	for i = minVal + 1, maxVal + 1 do
		local nextCount = map[i] or 0

		if nextCount ~= currentCount then
			table.insert(result, {currentStart, i - 1, currentCount})
			currentStart = i
			currentCount = nextCount
		end
	end

	return result
end

function coverage.Collect(key)
	local data = _G.__COVERAGE[key]

	if not data then return end

	local buffer = {}
	local list = {}

	for _, item in pairs(data.called) do
		table.insert(list, item)
	end

	table.sort(list, function(a, b)
		return a[1] < b[1]
	end)

	list = normalizeRanges(list)

	for _, item in ipairs(list) do
		table.insert(
			buffer,
			"{" .. table.concat(
					{
						tostring(item[1]),
						tostring(item[2]),
						tostring(item[3]),
					},
					","
				) .. "}"
		)
	end

	return "return {" .. table.concat(buffer, ",") .. "}"
end

return coverage
