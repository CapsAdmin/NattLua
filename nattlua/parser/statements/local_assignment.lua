local ReadIdentifier = require("nattlua.parser.expressions.identifier")
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values")
local ReadExpression = require("nattlua.parser.expressions.expression").expression

return function(parser)
	if not parser:IsCurrentValue("local") then return end
	local node = parser:Node("statement", "local_assignment")
	node:ExpectKeyword("local")
	node.left = ReadMultipleValues(parser, nil, ReadIdentifier)

	if parser:IsCurrentValue("=") then
		node:ExpectKeyword("=")
		node.right = ReadMultipleValues(parser, nil, ReadExpression, 0)
	end

	return node:End()
end

