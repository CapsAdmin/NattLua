--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

return
	{
		ReadInlineTypeCode = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if lexer:IsCurrentValue("§") then
				lexer:Advance(1)

				while not lexer:TheEnd() do
					if lexer:IsCurrentValue("\n") then break end
					lexer:Advance(1)
				end

				return "type_code"
			end

			return false
		end,
	}
