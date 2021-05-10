--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local syntax = require("nattlua.syntax.syntax")
return function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
	if syntax.IsSpace(lexer:GetCurrentChar()) then
		while not lexer:TheEnd() do
			lexer:Advance(1)
			if not syntax.IsSpace(lexer:GetCurrentChar()) then break end
		end

		return "space"
	end

	return false
end
