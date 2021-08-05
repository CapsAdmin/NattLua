local ExpectTypeExpression = require("nattlua.parser.expressions.typesystem.expression").ExpectExpression
return
	{
		ReadIdentifier = function(parser, expect_type)
			if not parser:IsType("letter") and not parser:IsValue("...") then return end
			local node = parser:Node("expression", "value")

			if parser:IsValue("...") then
				node.value = parser:ExpectValue("...")
			else
				node.value = parser:ExpectType("letter")
			end

			if parser:IsValue(":") or expect_type then
				node:ExpectKeyword(":")
				node.type_expression = ExpectTypeExpression(parser, 0)
			end

			return node:End()
		end,
	}
