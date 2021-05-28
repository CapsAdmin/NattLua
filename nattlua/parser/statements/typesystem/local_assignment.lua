local syntax = require("nattlua.syntax.syntax")
local type_expression_list = require("nattlua.parser.statements.typesystem.expression_list")
local identifier_list = require("nattlua.parser.statements.identifier_list")
return function(parser)
	if not (
		parser:IsCurrentValue("local") and parser:IsValue("type", 1) and
		syntax.GetTokenType(parser:GetToken(2)) == "letter"
	) then return end
	local node = parser:Node("statement", "local_assignment")
	node.tokens["local"] = parser:ReadValue("local")
	node.tokens["type"] = parser:ReadValue("type")
	node.left = identifier_list(parser)
	node.environment = "typesystem"

	if parser:IsCurrentValue("=") then
		node.tokens["="] = parser:ReadValue("=")
		node.right = type_expression_list(parser)
	end

	return node
end
