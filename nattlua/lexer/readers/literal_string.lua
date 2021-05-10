--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local helpers = require("nattlua.other.quote")
return function(lexer--[[#: Lexer]], multiline_comment--[[#: boolean]])--[[#: Tuple<|boolean|> | Tuple<|false, string|>]]
	local start = lexer.Position
	lexer:Advance(1)

	if lexer:IsCurrentValue("=") then
		while not lexer:TheEnd() do
			lexer:Advance(1)
			if not lexer:IsCurrentValue("=") then break end
		end
	end

	if not lexer:IsCurrentValue("[") then
		if multiline_comment then return false end
		return
			false,
			"expected " .. helpers.QuoteToken(lexer:GetChars(start, lexer.Position - 1) .. "[") .. " got " .. helpers.QuoteToken(lexer:GetChars(start, lexer.Position))
	end

	lexer:Advance(1)
	local closing = "]" .. string.rep("=", (lexer.Position - start) - 2) .. "]"
	local pos = lexer:FindNearest(closing)

	if pos then
		lexer:Advance(pos)
		return true
	end

	return false, "expected " .. helpers.QuoteToken(closing) .. " reached end of code"
end
