local ReadIdentifier = require("nattlua.parser.expressions.identifier")
local ExpectExpression = require("nattlua.parser.expressions.expression").expect_expression
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values")
return function(parser)
	if not parser:IsCurrentValue("for") then return nil end
	local node = parser:Node("statement", "generic_for")
	node:ExpectKeyword("for")
	node.identifiers = ReadMultipleValues(parser, nil, ReadIdentifier)
	node:ExpectKeyword("in")
	node.expressions = ReadMultipleValues(parser, math.huge, ExpectExpression, 0)
	return
		node:ExpectKeyword("do"):ExpectNodesUntil("end"):ExpectKeyword("end", "do"):End()
end
