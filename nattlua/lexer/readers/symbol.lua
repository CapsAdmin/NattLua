--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]


local syntax = require("nattlua.syntax.syntax")
return
	{
		ReadSymbol = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if lexer:ReadFirstFromArray(syntax.GetSymbols()) then return "symbol" end
			return false
		end,
	}
