return
	{
		ReadWhile = function(parser)
			if not parser:IsCurrentValue("while") then return nil end
			return
				parser:Node("statement", "while"):ExpectKeyword("while"):ExpectExpression():ExpectKeyword("do")
				:ExpectNodesUntil("end")
				:ExpectKeyword("end", "do")
				:End()
		end,
	}
