local optional_expression_list = require("nattlua.parser.expressions.expression").optional_expression_list
return function(parser)
	if not parser:IsCurrentValue("return") then return nil end
	local node = parser:Node("statement", "return"):ExpectKeyword("return")
	node.expressions = optional_expression_list(parser)
	return node:End()
end
