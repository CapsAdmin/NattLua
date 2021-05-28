return function(parser)
	return
		parser:IsCurrentValue("return") and
		parser:Node("statement", "return"):ExpectKeyword("return"):ExpectExpressionList():End()
end
