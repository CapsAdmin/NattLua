--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local syntax = require("nattlua.syntax.syntax")
return
	{
		ReadLetter = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if syntax.IsLetter(lexer:GetCurrentByteChar()) then
				while not lexer:TheEnd() do
					lexer:Advance(1)
					if not syntax.IsDuringLetter(lexer:GetCurrentByteChar()) then break end
				end

				return "letter"
			end

			return false
		end,
	}
