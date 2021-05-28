return function(parser)
	if not parser:IsCurrentValue("break") then return nil end

	return parser:Statement("break"):ExpectKeyword("break"):End()
end
