return function(parser)
	return
		parser:IsCurrentValue("for") and
		parser:Statement("generic_for"):ExpectKeyword("for"):ExpectIdentifierList():ExpectKeyword("in")
		:ExpectExpressionList()
		:ExpectKeyword("do")
		:ExpectStatementsUntil("end")
		:ExpectKeyword("end", "do")
		:End()
end
