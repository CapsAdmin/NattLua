return function(parser)
	return
		parser:IsCurrentValue("repeat") and
		parser:Node("statement", "repeat"):ExpectKeyword("repeat"):ExpectStatementsUntil("until")
		:ExpectKeyword("until")
		:ExpectExpression()
		:End()
end
