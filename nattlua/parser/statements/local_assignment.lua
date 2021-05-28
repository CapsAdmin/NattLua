local identifier_list = require("nattlua.parser.statements.identifier_list")
local expression_list = require("nattlua.parser.expressions.expression").expression_list

return function(parser)
	if not parser:IsCurrentValue("local") then return end
	local node = parser:Node("statement", "local_assignment")
	node:ExpectKeyword("local")
	node.left = identifier_list(parser)

	if parser:IsCurrentValue("=") then
		node:ExpectKeyword("=")
		node.right = expression_list(parser)
	end

	return node:End()
end
