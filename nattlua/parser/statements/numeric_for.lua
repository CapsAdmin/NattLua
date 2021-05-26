return function(parser)
	return
		parser:IsCurrentValue("for") and
		parser:IsValue("=", 2) and
		parser:Statement("numeric_for"):ExpectKeyword("for"):ExpectIdentifierList(1):ExpectKeyword("=")
		:ExpectExpressionList(3)
		:ExpectKeyword("do")
		:ExpectStatementsUntil("end")
		:ExpectKeyword("end", "do")
		:End()
end
