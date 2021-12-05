--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local syntax = require("nattlua.syntax.syntax")
return
	{
		ReadLetter = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if not syntax.IsLetter(lexer:GetCurrentByteChar()) then
				return false
			end
			
			while not lexer:TheEnd() do
				lexer:Advance(1)
				if not syntax.IsDuringLetter(lexer:GetCurrentByteChar()) then break end
			end

			return "letter"

		end,
	}
