return function(parser)
	return
		parser:IsCurrentValue("::") and
		parser:Statement("goto_label"):ExpectKeyword("::"):ExpectSimpleIdentifier():ExpectKeyword("::"):End()
end
