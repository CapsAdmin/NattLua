local math = require("math")
local ExpectExpression = require("nattlua.parser.expressions.expression").ExpectExpression
local ReadMultipleValues = require("nattlua.parser.statements.multiple_values").ReadMultipleValues
return
	{
		ReadCallOrAssignment = function(parser)
			local start = parser:GetToken()
			local left = ReadMultipleValues(parser, math.huge, ExpectExpression, 0)

			if parser:IsValue("=") then
				local node = parser:Node("statement", "assignment")
				node:ExpectKeyword("=")
				node.left = left
				node.right = ReadMultipleValues(parser, math.huge, ExpectExpression, 0)
				return node:End()
			end

			if left[1] and (left[1].kind == "postfix_call" or left[1].kind == "import") and not left[2] then
				local node = parser:Node("statement", "call_expression")
				node.value = left[1]
				node.tokens = left[1].tokens
				return node:End()
			end

			parser:Error(
				"expected assignment or call expression got $1 ($2)",
				start,
				parser:GetToken(),
				parser:GetToken().type,
				parser:GetToken().value
			)
		end,
	}
