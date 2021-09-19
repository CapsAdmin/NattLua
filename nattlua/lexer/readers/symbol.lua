--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]


local syntax = require("nattlua.syntax.syntax")
return
	{
		ReadSymbol = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if syntax.ReadSymbol(lexer) then return "symbol" end
			return false
		end,
	}
