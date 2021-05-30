--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

return
	{
		ReadMultilineCComment = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if lexer:IsValue("/", 0) and lexer:IsValue("*", 1) then
				lexer:Advance(2)

				while not lexer:TheEnd() do
					if lexer:IsValue("*", 0) and lexer:IsValue("/", 1) then
						lexer:Advance(2)

						break
					end

					lexer:Advance(1)
				end

				return "multiline_comment"
			end

			return false
		end,
	}
