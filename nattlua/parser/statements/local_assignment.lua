local identifier_list = require("nattlua.parser.statements.identifier_list")
return function(parser)
	if not parser:IsCurrentValue("local") then return end
	local node = parser:Statement("local_assignment")
	node:ExpectKeyword("local")
	node.left = identifier_list(parser)

	if parser:IsCurrentValue("=") then
		node:ExpectKeyword("=")
		node.right = parser:ReadExpressionList()
	end

	return node:End()
end
