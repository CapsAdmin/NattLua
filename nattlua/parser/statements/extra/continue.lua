return function(parser)
	return
		parser:IsCurrentValue("continue") and
		parser:Node("statement", "continue"):ExpectKeyword("continue"):End()
end
