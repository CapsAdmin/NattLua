--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local read_literal_string = require("nattlua.lexer.readers.literal_string")
return function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
	if
		lexer:IsValue("-", 0) and
		lexer:IsValue("-", 1) and
		lexer:IsValue("[", 2) and
		(lexer:IsValue("[", 3) or lexer:IsValue("=", 3))
	then
		local start = lexer.Position
		lexer:Advance(2)
		local ok, err = read_literal_string(lexer, true)

		if not ok then
			if err then
				lexer:Error("expected multiline comment to end: " .. err, start, start + 1)
				lexer:SetPosition(start + 2)
			else
				lexer:SetPosition(start)
			end

			return false
		end

		return "multiline_comment"
	end

	return false
end
