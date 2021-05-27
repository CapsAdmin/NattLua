local expression_list = require("nattlua.parser.statements.typesystem.expression_list")
return function(parser)
	if not (parser:IsCurrentValue("type") and (parser:IsType("letter", 1) or parser:IsValue("^", 1))) then return end
	local node = parser:Statement("assignment")
	node.tokens["type"] = parser:ReadValue("type")
	node.left = expression_list(parser)
	node.environment = "typesystem"

	if parser:IsCurrentValue("=") then
		node.tokens["="] = parser:ReadValue("=")
		node.right = expression_list(parser)
	end

	return node
end
