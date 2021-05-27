local math_huge = math.huge
local index_expression = require("nattlua.parser.expressions.index_expression")
return function(parser)
	if not (parser:IsCurrentValue("interface") and parser:IsType("letter", 1)) then return end
	local node = parser:Statement("type_interface")
	node.tokens["interface"] = parser:ReadValue("interface")
	node.key = index_expression(parser)
	node.tokens["{"] = parser:ReadValue("{")
	local list = {}

	for i = 1, math_huge do
		if not parser:IsCurrentType("letter") then break end
		local node = parser:Statement("interface_declaration")
		node.left = parser:ReadType("letter")
		node.tokens["="] = parser:ReadValue("=")
		node.right = parser:ReadTypeExpression()
		list[i] = node
	end

	node.expressions = list
	node.tokens["}"] = parser:ReadValue("}")
	return node
end
