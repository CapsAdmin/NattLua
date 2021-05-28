return function(parser)
	local node = parser:Node("expression", "value")

	if parser:IsCurrentValue("...") then
		node.value = parser:ReadValue("...")
	else
		node.value = parser:ReadType("letter")
	end

	if parser.ReadTypeExpression and parser:IsCurrentValue(":") then
		node:ExpectKeyword(":")
		node.as_expression = parser:ReadTypeExpression()
	end

	return node:End()
end
