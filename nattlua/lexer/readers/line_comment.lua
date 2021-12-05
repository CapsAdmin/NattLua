--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

return
	{
		ReadLineComment = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if not lexer:IsString("--") then
				return false
			end

			lexer:Advance(2)

			while not lexer:TheEnd() do
				if lexer:IsString("\n") then
					break 
				end
				
				lexer:Advance(1)
			end

			return "line_comment"
		end,
	}
