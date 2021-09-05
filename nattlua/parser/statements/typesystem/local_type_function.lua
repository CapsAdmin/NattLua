local ReadTypeFunctionBody = require("nattlua.parser.statements.typesystem.type_function_body").ReadTypeFunctionBody
return
	{
		ReadLocalTypeFunction = function(parser)
			if not (parser:IsValue("local") and parser:IsValue("function", 1) and (parser:IsValue("<|", 3) or parser:IsValue("!", 3))) then return end
			local node = parser:Node("statement", "local_type_function"):ExpectKeyword("local"):ExpectKeyword("function")
				:ExpectSimpleIdentifier()
			ReadTypeFunctionBody(parser, node)
			return node:End()
		end,
	}
