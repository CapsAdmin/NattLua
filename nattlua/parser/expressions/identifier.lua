
local type_expression = require("nattlua.parser.expressions.typesystem.expression").expression

return function(parser)
	local node = parser:Node("expression", "value")

	if parser:IsCurrentValue("...") then
		node.value = parser:ReadValue("...")
	else
		node.value = parser:ReadType("letter")
	end

	if parser:IsCurrentValue(":") then
		node:ExpectKeyword(":")
		node.as_expression = type_expression(parser)
	end

	return node:End()
end
