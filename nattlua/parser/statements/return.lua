return function(parser)
	return
		parser:IsCurrentValue("return") and
		parser:Statement("return"):ExpectKeyword("return"):ExpectExpressionList():End()
end