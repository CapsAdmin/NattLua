local ReadMultipleValues = require("nattlua.parser.statements.multiple_values").ReadMultipleValues
local ReadExpression = require("nattlua.parser.expressions.expression").ReadExpression
return
	{
		ReadReturn = function(parser)
			if not parser:IsCurrentValue("return") then return nil end
			local node = parser:Node("statement", "return"):ExpectKeyword("return")
			node.expressions = ReadMultipleValues(parser, nil, ReadExpression, 0)
			return node:End()
		end,
	}
