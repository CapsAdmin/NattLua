local ReadFunctionBody = require("nattlua.parser.statements.function_body").ReadFunctionBody
return
	{
		ReadFunction = function(parser)
			if not parser:IsValue("function") then return end
			local node = parser:Node("expression", "function"):ExpectKeyword("function")
			ReadFunctionBody(parser, node)
			return node:End()
		end,
	}
