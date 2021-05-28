local function_generics_body = require("nattlua.parser.statements.typesystem.function_generics_body")
local index_expression = require("nattlua.parser.expressions.index_expression")
return function(parser)
	if not (parser:IsValue("function") and parser:IsValue("<|", 2)) then return end
	local node = parser:Node("statement", "generics_type_function"):ExpectKeyword("function")
	node.expression = index_expression(parser)
	node:ExpectSimpleIdentifier()
	function_generics_body(parser, node)
	return node:End()
end
