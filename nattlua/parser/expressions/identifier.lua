local ExpectTypeExpression = require("nattlua.parser.expressions.typesystem.expression").expect_expression
return function(parser)
	local node = parser:Node("expression", "value")

	if parser:IsCurrentValue("...") then
		node.value = parser:ReadValue("...")
	else
		node.value = parser:ReadType("letter")
	end

	if parser:IsCurrentValue(":") then
		node:ExpectKeyword(":")
		node.as_expression = ExpectTypeExpression(parser, 0)
	end

	return node:End()
end
