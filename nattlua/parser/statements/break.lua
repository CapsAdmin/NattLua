return function(parser)
	return
        parser:IsCurrentValue("break") and
        parser:Statement("break"):ExpectKeyword("break"):End()
end