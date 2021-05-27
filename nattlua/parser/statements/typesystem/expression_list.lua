local math_huge = math.huge

local function handle_separator(parser, out, i, node)
	if not node then return true end
	out[i] = node
	if not parser:IsCurrentValue(",") and not parser:IsCurrentValue(";") then return true end

	if parser:IsCurrentValue(";") then
		node.tokens[","] = parser:ReadValue(";")
	else
		node.tokens[","] = parser:ReadValue(",")
	end
end

return function(parser, max)
	local out = {}

	for i = 1, math_huge do
		if handle_separator(parser, out, i, parser:ReadTypeExpression()) then break end

		if max then
			max = max - 1
			if max == 0 then break end
		end
	end

	return out
end
