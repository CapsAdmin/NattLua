--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local syntax = require("nattlua.syntax.syntax")
return
	{
		ReadSpace = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if syntax.IsSpace(lexer:GetCurrentByteChar()) then
				while not lexer:TheEnd() do
					lexer:Advance(1)
					if not syntax.IsSpace(lexer:GetCurrentByteChar()) then break end
				end

				return "space"
			end

			return false
		end,
	}
