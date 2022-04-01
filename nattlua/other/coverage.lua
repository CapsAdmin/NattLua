local coverage = {}
_G.__COVERAGE = _G.__COVERAGE or {}
coverage.collected = {}

function coverage.PreProcess(code, key)
	local nl = require("nattlua")
	local not_called = {}
	local compiler = nl.Compiler(
		code,
		"lol",
		{
			on_node = function(parser, node)
				if
					node.type == "expression" and
					not node.is_left_assignment and
					not node.is_identifier
				then
					if node.parent.kind == "binary_operator" then
						return
					end

					if node.kind == "function" then return end

					if node.kind == "table" then return end

					print(node.kind)
					local start, stop = node:GetStartStop()
					not_called[start .. "," .. stop] = {start, stop}
					local call_expression = parser:ParseString(" Æ('" .. start .. "," .. stop .. "') ").statements[1].value
					-- add comma to last expression since we're adding a new one
					call_expression.expressions[#call_expression.expressions].tokens[","] = parser:NewToken("symbol", ",")
					table.insert(call_expression.expressions, node)

					if node.right then call_expression.right = node.right end

					return call_expression
				end
			end,
			skip_import = true,
		}
	)
	assert(compiler:Parse())
	local original = compiler.Code:GetString()
	local lua = compiler:Emit()
	lua = [[
        local collected = _G.__COVERAGE["]] .. key .. [["].collected
        local function Æ(start_stop, ...) 
            collected[start_stop] = true
            return ...
        end
        
        ]] .. lua
	_G.__COVERAGE[key] = _G.__COVERAGE[key] or
		{collected = {}, not_called = not_called, compiler = compiler}
	return lua
end

function coverage.GetAll()
	return _G.__COVERAGE
end

function coverage.Collect(key)
	print(key)

	for k, v in pairs(_G.__COVERAGE) do
		print(k, v)
	end

	local collected = _G.__COVERAGE[key].collected
	local not_called = _G.__COVERAGE[key].not_called
	local compiler = _G.__COVERAGE[key].compiler

	for k in pairs(collected) do
		not_called[k] = nil
	end

	local original = compiler.Code:GetString()
	local buffer = {}

	for i = 1, #original do
		buffer[i] = original:sub(i, i)
	end

	for _, start_stop in pairs(not_called) do
		local start, stop = unpack(start_stop)

		for i = start, stop do
			buffer[i] = " "
		end
	end

	print(table.concat(buffer))
end

return coverage
