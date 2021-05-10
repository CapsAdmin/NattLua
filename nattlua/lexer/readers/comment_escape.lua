--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

return
	{
		read = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if
				lexer:IsValue("-", 0) and
				lexer:IsValue("-", 1) and
				lexer:IsValue("[", 2) and
				lexer:IsValue("[", 3) and
				lexer:IsValue("#", 4)
			then
				lexer:Advance(5)
				lexer.comment_escape = string.char(lexer:GetCurrentChar())
				return "comment_escape"
			end

			return false
		end,
		read_remaining = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if lexer.comment_escape and lexer:IsValue("]", 0) and lexer:IsValue("]", 1) then
				lexer:Advance(2)
				return "comment_escape"
			end

			return false
		end,
	}
