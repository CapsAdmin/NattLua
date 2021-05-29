local math  = require("math")
local ReadIdentifier = require("nattlua.parser.expressions.identifier").ReadIdentifier
local ExpectExpression = require("nattlua.parser.expressions.expression").ExpectExpression
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values").ReadMultipleValues
return
	{
		ReadGenericFor = function(parser)
			if not parser:IsCurrentValue("for") then return nil end
			local node = parser:Node("statement", "generic_for")
			node:ExpectKeyword("for")
			node.identifiers = ReadMultipleValues(parser, nil, ReadIdentifier)
			node:ExpectKeyword("in")
			node.expressions = ReadMultipleValues(parser, math.huge, ExpectExpression, 0)
			return
				node:ExpectKeyword("do"):ExpectNodesUntil("end"):ExpectKeyword("end", "do"):End()
		end,
	}
