return function(parser)
	return
		parser:IsCurrentValue("repeat") and
		parser:Node("statement", "repeat"):ExpectKeyword("repeat"):ExpectNodesUntil("until")
		:ExpectKeyword("until")
		:ExpectExpression()
		:End()
end
