local function_body = require("nattlua.parser.statements.function_body")

return function(parser)
	if not (parser:IsCurrentValue("local") and parser:IsValue("function", 1)) then return end
	local node = parser:Statement("local_function"):ExpectKeyword("local"):ExpectKeyword("function")
		:ExpectSimpleIdentifier()
	function_body(parser, node)
	return node:End()
end
