local ReadMultipleValues = require("nattlua.parser.statements.multiple_values")
local ReadIdentifier = require("nattlua.parser.expressions.identifier")
local multiple_values = require("nattlua.parser.statements.multiple_values")
local type_expression = require("nattlua.parser.expressions.typesystem.expression").expression
return function(parser, node)
	node:ExpectAliasedKeyword("(", "arguments(")
	node.identifiers = ReadMultipleValues(parser, nil, ReadIdentifier)
	node:ExpectAliasedKeyword(")", "arguments)", "arguments)")

	if parser:IsCurrentValue(":") then
		node.tokens[":"] = parser:ReadValue(":")
		node.return_types = multiple_values(parser, nil, type_expression)
	end

	node:ExpectNodesUntil("end")
	node:ExpectKeyword("end", "function")
	return node
end
