return function(parser)
	if not parser:IsCurrentValue("::") then return nil end
	return
		parser:Node("statement", "goto_label"):ExpectKeyword("::"):ExpectSimpleIdentifier():ExpectKeyword("::")
		:End()
end
