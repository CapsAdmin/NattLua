return function(parser, node)
	node:ExpectAliasedKeyword("(", "arguments(")
	node:ExpectIdentifierList()
	node:ExpectAliasedKeyword(")", "arguments)", "arguments)")
	parser:ReadExplicitFunctionReturnType(node)
	node:ExpectStatementsUntil("end")
	node:ExpectKeyword("end", "function")
	return node
end