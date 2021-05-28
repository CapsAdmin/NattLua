local type_expression_list = require("nattlua.parser.expressions.typesystem.expression").expression_list
return function(parser)
	if not (parser:IsCurrentValue("type") and (parser:IsType("letter", 1) or parser:IsValue("^", 1))) then return end
	local node = parser:Node("statement", "assignment")
	node.tokens["type"] = parser:ReadValue("type")
	node.left = type_expression_list(parser)
	node.environment = "typesystem"

	if parser:IsCurrentValue("=") then
		node.tokens["="] = parser:ReadValue("=")
		node.right = type_expression_list(parser)
	end

	return node
end
