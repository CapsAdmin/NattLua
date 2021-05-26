return function(parser)
	return
		parser:IsCurrentValue("continue") and
		parser:Statement("continue"):ExpectKeyword("continue"):End()
end
