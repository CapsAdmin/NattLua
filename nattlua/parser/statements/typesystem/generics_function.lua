local ReadFunctionGenericsBody = require("nattlua.parser.statements.typesystem.function_generics_body").ReadFunctionGenericsBody
local ReadIndexExpression = require("nattlua.parser.expressions.index_expression").ReadIndexExpression
return
	{
		ReadGenericsFunction = function(parser)
			if not (parser:IsValue("function") and parser:IsValue("<|", 2)) then return end
			local node = parser:Node("statement", "generics_type_function"):ExpectKeyword("function")
			node.expression = ReadIndexExpression(parser)
			node:ExpectSimpleIdentifier()
			ReadFunctionGenericsBody(parser, node)
			return node:End()
		end,
	}
