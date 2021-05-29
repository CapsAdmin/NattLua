local identifier_list = require("nattlua.parser.statements.identifier_list")
local multiple_values = require("nattlua.parser.statements.multiple_values")
local type_expression = require("nattlua.parser.expressions.typesystem.expression").expression
return function(parser, node)
	node:ExpectAliasedKeyword("(", "arguments(")
	node.identifiers = identifier_list(parser)
	node:ExpectAliasedKeyword(")", "arguments)", "arguments)")

	if parser:IsCurrentValue(":") then
		node.tokens[":"] = parser:ReadValue(":")
		node.return_types = multiple_values(parser, nil, type_expression)
	end

	node:ExpectNodesUntil("end")
	node:ExpectKeyword("end", "function")
	return node
end
