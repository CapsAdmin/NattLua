local function_body = require("nattlua.parser.statements.function_body").ReadFunctionBody
return
	{
		ReadLocalFunction = function(parser)
			if not (parser:IsValue("local") and parser:IsValue("function", 1)) then return end
			local node = parser:Node("statement", "local_function"):ExpectKeyword("local"):ExpectKeyword("function")
				:ExpectSimpleIdentifier()
			function_body(parser, node)
			return node:End()
		end,
	}
