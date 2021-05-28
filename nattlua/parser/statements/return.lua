local expression_list = require("nattlua.parser.expressions.expression").expression_list

return function(parser)
	if not parser:IsCurrentValue("return") then return nil end
	local node = parser:Node("statement", "return"):ExpectKeyword("return")
	node.expressions = expression_list(parser)
	return node:End()
end
