return function(parser)
	return
		parser:IsCurrentValue("do") and
		parser:Statement("do"):ExpectKeyword("do"):ExpectStatementsUntil("end"):ExpectKeyword("end", "do")
		:End()
end
