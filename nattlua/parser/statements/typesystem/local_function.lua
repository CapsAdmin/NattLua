local ReadFunctionBody = require("nattlua.parser.statements.typesystem.function_body").ReadFunctionBody
return
	{
		ReadLocalFunction = function(parser)
			if not (parser:IsCurrentValue("local") and parser:IsValue("type", 1) and parser:IsValue("function", 2)) then return end
			local node = parser:Node("statement", "local_type_function"):ExpectKeyword("local"):ExpectKeyword("type")
				:ExpectKeyword("function")
				:ExpectSimpleIdentifier()
			ReadFunctionBody(parser, node, true)
			return node:End()
		end,
	}
