return
{
	ReadAnalyzerFunction = function(parser)
		local ReadAnalyzerFunctionBody = require("nattlua.parser.statements.typesystem.analyzer_function_body").ReadAnalyzerFunctionBody
			if not parser:IsValue("analyzer") or not parser:IsValue("function", 1) then return end
			local node = parser:Node("expression", "analyzer_function"):ExpectKeyword("analyzer"):ExpectKeyword("function")
            ReadAnalyzerFunctionBody(parser, node)
			return node:End()
		end,
	}
