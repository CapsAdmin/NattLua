local nl = require("nattlua")

local function is_left_assignment(node)
	while node do
		if node.is_left_assignment then return true end

		node = node.parent
	end

	return false
end

local compiler = nl.File(
	"examples/balance_analysis.lua",
	{
		on_node = function(parser, node)
			if
				node.type == "expression" and
				node.kind ~= "value" and
				not is_left_assignment(node)
			then
				if node.kind == "binary_operator" and node.value.value == ":" then
					return
				end

				local start, stop = node:GetStartStop()
				local call_expression = parser:ParseString(" Æ('" .. start .. "," .. stop .. "') ").statements[1].value
				call_expression.expressions[#call_expression.expressions].tokens[","] = parser:NewToken("symbol", ",")
				table.insert(call_expression.expressions, node)

				if node.right then call_expression.right = node.right end

				return call_expression
			end
		--print(node)
		end,
		skip_import = true,
	}
)
assert(compiler:Parse())
local original = compiler.Code:GetString()
local lua = compiler:Emit()
lua = [[
	__CALLED = {}
	local function Æ(start_stop, ...) 
		__CALLED[start_stop] = true
		return ...
	end
	
	]] .. lua
print(lua)
print(loadstring(lua)())
local buffer = {}

for i = 1, #original do
	buffer[i] = original:sub(i, i)
end

for k, v in pairs(__CALLED) do
	local start, stop = k:match("^(%d+),(%d+)$")
	start = tonumber(start)
	stop = tonumber(stop)

	for i = start, stop do
		buffer[i] = " "
	end
end

print(table.concat(buffer))
