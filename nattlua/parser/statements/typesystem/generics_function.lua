local ReadTypeFunctionBody = require("nattlua.parser.statements.typesystem.type_function_body").ReadTypeFunctionBody
local ReadIndexExpression = require("nattlua.parser.expressions.index_expression").ReadIndexExpression
return
	{
		ReadGenericsFunction = function(parser)
			if not (parser:IsValue("function") and parser:IsValue("<|", 2)) then return end
			local node = parser:Node("statement", "type_function"):ExpectKeyword("function")
			node.expression = ReadIndexExpression(parser)
			node:ExpectSimpleIdentifier()
			ReadTypeFunctionBody(parser, node)
			return node:End()
		end,
	}
