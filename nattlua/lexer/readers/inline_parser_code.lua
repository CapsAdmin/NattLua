--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

return
	{
		ReadInlineParserCode = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if not lexer:IsString("£") then
				return false
			end

			lexer:Advance(#"£")

			while not lexer:TheEnd() do
				if lexer:IsString("\n") then
					break
				end
				lexer:Advance(1)
			end

			return "parser_code"
		end,
	}
