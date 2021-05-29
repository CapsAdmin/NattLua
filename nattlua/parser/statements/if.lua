local ExpectExpression = require("nattlua.parser.expressions.expression").ExpectExpression
return
	{
		ReadIf = function(parser)
			if not parser:IsCurrentValue("if") then return nil end
			local node = parser:Node("statement", "if")
			node.expressions = {}
			node.statements = {}
			node.tokens["if/else/elseif"] = {}
			node.tokens["then"] = {}

			for i = 1, parser:GetLength() do
				local token

				if i == 1 then
					token = parser:ReadValue("if")
				else
					token = parser:ReadValues(
						{
							["else"] = true,
							["elseif"] = true,
							["end"] = true,
						}
					)
				end

				if not token then return end
				node.tokens["if/else/elseif"][i] = token

				if token.value ~= "else" then
					node.expressions[i] = ExpectExpression(parser, 0)
					node.tokens["then"][i] = parser:ReadValue("then")
				end

				node.statements[i] = parser:ReadNodes({
					["end"] = true,
					["else"] = true,
					["elseif"] = true,
				})
				if parser:IsCurrentValue("end") then break end
			end

			node:ExpectKeyword("end")
			return node:End()
		end,
	}
