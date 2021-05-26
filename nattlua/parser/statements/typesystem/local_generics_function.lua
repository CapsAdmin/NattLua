local function_generics_body = require("nattlua.parser.statements.typesystem.function_generics_body")
return function(parser)
	if not (parser:IsCurrentValue("local") and parser:IsValue("function", 1) and parser:IsValue("<|", 3)) then return end
	local node = parser:Statement("local_generics_type_function"):ExpectKeyword("local"):ExpectKeyword("function")
		:ExpectSimpleIdentifier()
	function_generics_body(parser, node)
	return node:End()
end
