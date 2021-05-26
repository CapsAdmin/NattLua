local syntax = require("nattlua.syntax.syntax")
return function(parser)
	if not (
		parser:IsCurrentValue("local") and parser:IsValue("type", 1) and
		syntax.GetTokenType(parser:GetToken(2)) == "letter"
	) then return end
	local node = parser:Statement("local_assignment")
	node.tokens["local"] = parser:ReadValue("local")
	node.tokens["type"] = parser:ReadValue("type")
	node.left = parser:ReadIdentifierList()
	node.environment = "typesystem"

	if parser:IsCurrentValue("=") then
		node.tokens["="] = parser:ReadValue("=")
		node.right = parser:ReadTypeExpressionList()
	end

	return node
end
