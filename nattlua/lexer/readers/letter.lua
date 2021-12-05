--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local characters = require("nattlua.syntax.characters")
return
	{
		ReadLetter = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if not characters.IsLetter(lexer:PeekByte()) then
				return false
			end
			
			while not lexer:TheEnd() do
				lexer:Advance(1)
				if not characters.IsDuringLetter(lexer:PeekByte()) then break end
			end

			return "letter"

		end,
	}
