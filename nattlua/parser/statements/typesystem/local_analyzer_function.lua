local ReadAnalyzerFunctionBody = require("nattlua.parser.statements.typesystem.analyzer_function_body").ReadAnalyzerFunctionBody
return
	{
		ReadLocalAnalyzerFunction = function(parser)
			if not (parser:IsValue("local") and parser:IsValue("analyzer", 1) and parser:IsValue("function", 2)) then return end
			local node = parser:Node("statement", "local_analyzer_function"):ExpectKeyword("local"):ExpectKeyword("analyzer")
				:ExpectKeyword("function")
				:ExpectSimpleIdentifier()
			ReadAnalyzerFunctionBody(parser, node, true)
			return node:End()
		end,
	}
