return function(parser)
	return
		parser:IsCurrentValue("goto") and
		parser:IsType("letter", 1) and
		parser:Statement("goto"):ExpectKeyword("goto"):ExpectSimpleIdentifier():End()
end
