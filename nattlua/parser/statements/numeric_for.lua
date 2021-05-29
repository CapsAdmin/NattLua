local ReadIdentifier = require("nattlua.parser.expressions.identifier").ReadIdentifier
local ExpectExpression = require("nattlua.parser.expressions.expression").ExpectExpression
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values").ReadMultipleValues
return
	{
		ReadNumericFor = function(parser)
			if not (parser:IsCurrentValue("for") and parser:IsValue("=", 2)) then return nil end
			local node = parser:Node("statement", "numeric_for")
			node:ExpectKeyword("for")
			node.identifiers = ReadMultipleValues(parser, 1, ReadIdentifier)
			node:ExpectKeyword("=")
			node.expressions = ReadMultipleValues(parser, 3, ExpectExpression, 0)
			return
				node:ExpectKeyword("do"):ExpectNodesUntil("end"):ExpectKeyword("end", "do"):End()
		end,
	}
