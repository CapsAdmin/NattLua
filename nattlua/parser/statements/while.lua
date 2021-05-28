return function(parser)
	return
		parser:IsCurrentValue("while") and
		parser:Node("statement", "while"):ExpectKeyword("while"):ExpectExpression():ExpectKeyword("do")
		:ExpectStatementsUntil("end")
		:ExpectKeyword("end", "do")
		:End()
end
