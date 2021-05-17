--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

return
	{
		line_comment = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if lexer:IsValue("-", 0) and lexer:IsValue("-", 1) then
				lexer:Advance(#"--")

				while not lexer:TheEnd() do
					if lexer:IsCurrentValue("\n") then break end
					lexer:Advance(1)
				end

				return "line_comment"
			end

			return false
		end,
	}
