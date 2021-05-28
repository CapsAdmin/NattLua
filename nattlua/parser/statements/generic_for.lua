return function(parser)
	if not parser:IsCurrentValue("for") then return nil end
	return
		parser:Node("statement", "generic_for"):ExpectKeyword("for"):ExpectIdentifierList():ExpectKeyword("in")
		:ExpectExpressionList()
		:ExpectKeyword("do")
		:ExpectStatementsUntil("end")
		:ExpectKeyword("end", "do")
		:End()
end
