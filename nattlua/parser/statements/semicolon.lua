return
	{
		ReadSemicolon = function(parser)
			if not parser:IsValue(";") then return nil end
			local node = parser:Node("statement", "semicolon")
			node.tokens[";"] = parser:ExpectValue(";")
			return node:End()
		end,
	}
