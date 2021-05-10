--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local BuildReadFunction = require("nattlua.lexer.build_read_function")
local syntax = require("nattlua.syntax.syntax")
local read = BuildReadFunction(syntax.GetSymbols(), false)
return function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
	if read(lexer) then return "symbol" end
	return false
end
