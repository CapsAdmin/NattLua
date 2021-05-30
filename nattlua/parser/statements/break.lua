return
	{
		ReadBreak = function(parser)
			if not parser:IsValue("break") then return nil end
			return parser:Node("statement", "break"):ExpectKeyword("break"):End()
		end,
	}
