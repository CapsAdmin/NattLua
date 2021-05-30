local ExpectTypeExpression = require("nattlua.parser.expressions.typesystem.expression").ExpectExpression
return
	{
		ReadIdentifier = function(parser)
			if not parser:IsType("letter") and not parser:IsValue("...") then return end
			local node = parser:Node("expression", "value")

			if parser:IsValue("...") then
				node.value = parser:ReadValue("...")
			else
				node.value = parser:ReadType("letter")
			end

			if parser:IsValue(":") then
				node:ExpectKeyword(":")
				node.as_expression = ExpectTypeExpression(parser, 0)
			end

			return node:End()
		end,
	}
