local ExpectExpression = require("nattlua.parser.expressions.expression").ExpectExpression
return
	{
		ReadWhile = function(parser)
			if not parser:IsValue("while") then return nil end
			local node = parser:Node("statement", "while"):ExpectKeyword("while")
			node.expression = ExpectExpression(parser)
			return
				node:ExpectKeyword("do"):ExpectNodesUntil("end"):ExpectKeyword("end", "do"):End()
		end,
	}
