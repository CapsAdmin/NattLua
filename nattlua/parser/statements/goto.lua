return
	{
		ReadGoto = function(parser)
			if not parser:IsValue("goto") then return nil end
			return
				parser:IsType("letter", 1) and
				parser:Node("statement", "goto"):ExpectKeyword("goto"):ExpectSimpleIdentifier():End()
		end,
	}
