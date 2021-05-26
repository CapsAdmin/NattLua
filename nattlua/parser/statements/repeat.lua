return function(parser)
	return
		parser:IsCurrentValue("repeat") and
		parser:Statement("repeat"):ExpectKeyword("repeat"):ExpectStatementsUntil("until"):ExpectKeyword("until")
		:ExpectExpression()
		:End()
end
