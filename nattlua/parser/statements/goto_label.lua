return function(parser)
	if not parser:IsCurrentValue("::") then return nil end

	return parser:Statement("goto_label"):ExpectKeyword("::"):ExpectSimpleIdentifier():ExpectKeyword("::"):End()
end
