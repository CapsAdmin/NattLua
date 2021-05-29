local syntax = require("nattlua.syntax.syntax")
local type_expression_list = require("nattlua.parser.expressions.typesystem.expression").expression_list
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values")
local ReadIdentifier = require("nattlua.parser.expressions.identifier")
return function(parser)
	if not (
		parser:IsCurrentValue("local") and parser:IsValue("type", 1) and
		syntax.GetTokenType(parser:GetToken(2)) == "letter"
	) then return end
	local node = parser:Node("statement", "local_assignment")
	node.tokens["local"] = parser:ReadValue("local")
	node.tokens["type"] = parser:ReadValue("type")
	node.left = ReadMultipleValues(parser, nil, ReadIdentifier)
	node.environment = "typesystem"

	if parser:IsCurrentValue("=") then
		node.tokens["="] = parser:ReadValue("=")
		node.right = type_expression_list(parser)
	end

	return node
end
