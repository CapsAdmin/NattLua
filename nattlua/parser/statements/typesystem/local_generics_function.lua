local ReadFunctionGenericsBody = require("nattlua.parser.statements.typesystem.function_generics_body").ReadFunctionGenericsBody
return
	{
		ReadLocalGenericsFunction = function(parser)
			if not (parser:IsValue("local") and parser:IsValue("function", 1) and parser:IsValue("<|", 3)) then return end
			local node = parser:Node("statement", "local_generics_type_function"):ExpectKeyword("local"):ExpectKeyword("function")
				:ExpectSimpleIdentifier()
			ReadFunctionGenericsBody(parser, node)
			return node:End()
		end,
	}
