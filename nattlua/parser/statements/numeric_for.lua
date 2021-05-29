local ReadIdentifier = require("nattlua.parser.expressions.identifier")
local ExpectExpression = require("nattlua.parser.expressions.expression").expect_expression
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values")
return function(parser)
	if not (parser:IsCurrentValue("for") and parser:IsValue("=", 2)) then return nil end
	local node = parser:Node("statement", "numeric_for")
	node:ExpectKeyword("for")
	node.identifiers = ReadMultipleValues(parser, 1, ReadIdentifier)
	node:ExpectKeyword("=")
	node.expressions = ReadMultipleValues(parser, 3, ExpectExpression, 0)
	return
		node:ExpectKeyword("do"):ExpectNodesUntil("end"):ExpectKeyword("end", "do"):End()
end
