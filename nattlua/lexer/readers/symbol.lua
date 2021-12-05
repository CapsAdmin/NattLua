--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]


local runtime_syntax = require("nattlua.syntax.runtime")
return
	{
		ReadSymbol = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if lexer:ReadFirstFromArray(runtime_syntax:GetSymbols()) then return "symbol" end
			return false
		end,
	}
