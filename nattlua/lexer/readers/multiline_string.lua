--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local read_literal_string = require("nattlua.lexer.readers.literal_string")
return function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
	if lexer:IsValue("[", 0) and (lexer:IsValue("[", 1) or lexer:IsValue("=", 1)) then
		local start = lexer.Position
		local ok, err = read_literal_string(lexer, false)

		if not ok and err then
			if err then -- TODO, err is nil | string
            	lexer:Error("expected multiline string to end: " .. err, start, start + 1)
			end
		end

		return "string"
	end

	return false
end
