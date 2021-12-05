--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

return
	{
		ReadMultilineCComment = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if not lexer:IsString("/*") then
				return false
			end

			local start = lexer:GetPosition()
			lexer:Advance(2)

			while not lexer:TheEnd() do
				if lexer:IsString("*/") then
					lexer:Advance(2)
					return "multiline_comment"
				end

				lexer:Advance(1)
			end

			lexer:Error(
				"expected multiline c comment to end, reached end of code",
				start,
				start + 1
			)

			return false
		end,
	}
