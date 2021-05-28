return function(parser)
	if not parser:IsCurrentValue("do") then return nil end
	return
		parser:Node("statement", "do"):ExpectKeyword("do"):ExpectStatementsUntil("end"):ExpectKeyword("end", "do")
		:End()
end
