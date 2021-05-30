return
	{
		ReadGotoLabel = function(parser)
			if not parser:IsValue("::") then return nil end
			return
				parser:Node("statement", "goto_label"):ExpectKeyword("::"):ExpectSimpleIdentifier():ExpectKeyword("::")
				:End()
		end,
	}
