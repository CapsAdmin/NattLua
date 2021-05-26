return function(parser)
	if not (parser:IsCurrentValue("type") and (parser:IsType("letter", 1) or parser:IsValue("^", 1))) then return end
	local node = parser:Statement("assignment")
	node.tokens["type"] = parser:ReadValue("type")
	node.left = parser:ReadTypeExpressionList()
	node.environment = "typesystem"

	if parser:IsCurrentValue("=") then
		node.tokens["="] = parser:ReadValue("=")
		node.right = parser:ReadTypeExpressionList()
	end

	return node
end
