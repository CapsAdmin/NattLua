--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local characters = require("nattlua.syntax.characters")
return
	{
		ReadSpace = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if characters.IsSpace(lexer:GetCurrentByteChar()) then
				while not lexer:TheEnd() do
					lexer:Advance(1)
					if not characters.IsSpace(lexer:GetCurrentByteChar()) then break end
				end

				return "space"
			end

			return false
		end,
	}
