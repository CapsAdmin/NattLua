local ExpectExpression = require("nattlua.parser.expressions.expression").ExpectExpression
return
	{
		ReadIf = function(parser)
			if not parser:IsValue("if") then return nil end
			local node = parser:Node("statement", "if")
			node.expressions = {}
			node.statements = {}
			node.tokens["if/else/elseif"] = {}
			node.tokens["then"] = {}

			for i = 1, parser:GetLength() do
				local token

				if i == 1 then
					token = parser:ExpectValue("if")
				else
					token = parser:ReadValues(
						{
							["else"] = true,
							["elseif"] = true,
							["end"] = true,
						}
					)
				end

				if not token then return end -- TODO: what happens here? :End is never called
				node.tokens["if/else/elseif"][i] = token

				if token.value ~= "else" then
					node.expressions[i] = ExpectExpression(parser, 0)
					node.tokens["then"][i] = parser:ExpectValue("then")
				end

				node.statements[i] = parser:ReadNodes({
					["end"] = true,
					["else"] = true,
					["elseif"] = true,
				})
				if parser:IsValue("end") then break end
			end

			node:ExpectKeyword("end")
			return node:End()
		end,
	}
