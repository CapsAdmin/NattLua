return
	{
		ReadBreak = function(parser)
			if not parser:IsCurrentValue("break") then return nil end
			return parser:Node("statement", "break"):ExpectKeyword("break"):End()
		end,
	}
