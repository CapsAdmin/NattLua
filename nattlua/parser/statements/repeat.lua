local ExpectExpression = require("nattlua.parser.expressions.expression").ExpectExpression
return
	{
		ReadRepeat = function(parser)
			if not parser:IsValue("repeat") then return nil end
			local node = parser:Node("statement", "repeat"):ExpectKeyword("repeat"):ExpectNodesUntil("until"):ExpectKeyword("until")
			node.expression = ExpectExpression(parser)
			return node:End()
		end,
	}
