local function_body = require("nattlua.parser.statements.typesystem.function_body")
return function(parser)
	if not (parser:IsCurrentValue("local") and parser:IsValue("type", 1) and parser:IsValue("function", 2)) then return end
	local node = parser:Statement("local_type_function"):ExpectKeyword("local"):ExpectKeyword("type"):ExpectKeyword("function")
		:ExpectSimpleIdentifier()
	function_body(parser, node, true)
	return node:End()
end
