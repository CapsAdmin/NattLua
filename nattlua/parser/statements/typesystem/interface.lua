local math_huge = math.huge
return function(parser)
	if not (parser:IsCurrentValue("interface") and parser:IsType("letter", 1)) then return end
	local node = parser:Statement("type_interface")
	node.tokens["interface"] = parser:ReadValue("interface")
	node.key = parser:ReadIndexExpression()
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
