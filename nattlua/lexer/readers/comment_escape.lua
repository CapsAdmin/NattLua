--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

return
	{
		ReadCommentEscape = function(lexer--[[#: Lexer & {comment_escape = boolean | nil}]])--[[#: TokenReturnType]]
			if
				lexer:IsValue("-", 0) and
				lexer:IsValue("-", 1) and
				lexer:IsValue("[", 2) and
				lexer:IsValue("[", 3) and
				lexer:IsValue("#", 4)
			then
				lexer:Advance(5)
				lexer.comment_escape = true
				return "comment_escape"
			end

			return false
		end,
		ReadRemainingCommentEscape = function(lexer--[[#: Lexer & {comment_escape = boolean | nil}]])--[[#: TokenReturnType]]
			if lexer.comment_escape and lexer:IsValue("]", 0) and lexer:IsValue("]", 1) then
				lexer:Advance(2)
				return "comment_escape"
			end

			return false
		end,
	}
