local identifier_list = require("nattlua.parser.statements.identifier_list")
return function(parser, node)
	node:ExpectAliasedKeyword("(", "arguments(")
	node.identifiers = identifier_list(parser)
	node:ExpectAliasedKeyword(")", "arguments)", "arguments)")
	parser:ReadExplicitFunctionReturnType(node)
	node:ExpectNodesUntil("end")
	node:ExpectKeyword("end", "function")
	return node
end
