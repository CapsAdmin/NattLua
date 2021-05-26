return function(parser)
	return
		parser:IsCurrentValue("while") and
		parser:Statement("while"):ExpectKeyword("while"):ExpectExpression():ExpectKeyword("do")
		:ExpectStatementsUntil("end")
		:ExpectKeyword("end", "do")
		:End()
end
