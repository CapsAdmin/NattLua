local coverage = {}
_G.__COVERAGE = _G.__COVERAGE or {}
coverage.collected = {}
local nl = require("nattlua")
local FUNC_NAME = "__CLCT"

function coverage.Preprocess(code, key)
	local expressions = {}

	local function inject_call_expression(parser, node, start, stop)
		local call_expression = parser:ParseString(" " .. FUNC_NAME .. "(" .. start .. "," .. stop .. ",x)").statements[1].value

		if node.kind == "postfix_call" and not node.tokens["call("] then
			node.tokens["call("] = parser:NewToken("symbol", "(")
			node.tokens["call)"] = parser:NewToken("symbol", ")")
		end

		-- replace "x" with the new node
		call_expression.expressions[3] = node

		if node.right then call_expression.right = node.right end

		table.insert(expressions, node)
		-- to prevent start stop messing up from previous injections
		call_expression.code_start = node.code_start
		call_expression.code_stop = node.code_stop
		return call_expression
	end

	local compiler = nl.Compiler(
		code,
		key,
		{
			on_parsed_node = function(parser, node)
				if node.type == "statement" then
					if node.kind == "call_expression" then
						local start, stop = node:GetStartStop()
						node.value = inject_call_expression(parser, node.value, start, stop)
					end
				elseif node.type == "expression" then
					local start, stop = node:GetStartStop()

					if
						node.is_left_assignment or
						node.is_identifier or
						node:GetStatement().kind == "function" or
						(
							node.kind == "binary_operator" and
							(
								node.value.value == "." or
								node.value.value == ":"
							)
						)
						or
						(
							node.parent and
							node.parent.kind == "binary_operator" and
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

	if code:find("clock_gettime", nil, true) then
		function _G.diff(input, expect)
			local a = os.tmpname()
			local b = os.tmpname()

			do
				local f = assert(io.open(a, "w"))
				f:write(input)
				f:close()
			end

			do
				local f = assert(io.open(b, "w"))
				f:write(expect)
				f:close()
			end

			os.execute("meld " .. a .. " " .. b)
		end

		local old = code
		local new = gen

		for i = 1, 100 do
			local temp, count = new:gsub(" __CLCT%b()", function(str)
				return str:match("^ __CLCT%(%d+,%d+,(.+)%)")
			end)

			if count == 0 then break end

			new = temp
		end

		diff(new, old)
	end

	lua = lua .. gen
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

local MASK = " "

function coverage.Collect(key)
	local data = _G.__COVERAGE[key]

	if not data then return end

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

		if not called[start .. ", " .. stop] then
			for i = start, stop do
				not_called[i] = true
			end
		end
	end

	for _, start_stop in pairs(called) do
		local start, stop, count = start_stop[1], start_stop[2], start_stop[3]
		buffer[start] = "--[[" .. count .. "]]" .. buffer[start]
	end

	return table.concat(buffer)
end

return coverage
