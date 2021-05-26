return function(parser)
	if not parser:IsCurrentValue("local") then return end
	local node = parser:Statement("local_assignment")
	node:ExpectKeyword("local")
	node.left = parser:ReadIdentifierList()

	if parser:IsCurrentValue("=") then
		node:ExpectKeyword("=")
		node.right = parser:ReadExpressionList()
	end

	return node:End()
end
