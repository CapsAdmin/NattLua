--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local string = require("string")
local helpers = require("nattlua.other.quote")
return
	{
		multiline_string = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if lexer:IsValue("[", 0) and (lexer:IsValue("[", 1) or lexer:IsValue("=", 1)) then
				local start = lexer:GetPosition()
				lexer:Advance(1)

				if lexer:IsCurrentValue("=") then
					while not lexer:TheEnd() do
						lexer:Advance(1)
						if not lexer:IsCurrentValue("=") then break end
					end
				end

				if not lexer:IsCurrentValue("[") then
					lexer:Error(
						"expected multiline string " .. helpers.QuoteToken(lexer:GetChars(start, lexer:GetPosition() - 1) .. "[") .. " got " .. helpers.QuoteToken(lexer:GetChars(start, lexer:GetPosition())),
						start,
						start + 1
					)
					return false
				end

				lexer:Advance(1)
				local closing = "]" .. string.rep("=", (lexer:GetPosition() - start) - 2) .. "]"
				local pos = lexer:FindNearest(closing)

				if pos then
					lexer:SetPosition(pos)
					return "string"
				end

				lexer:Error(
					"expected multiline string " .. helpers.QuoteToken(closing) .. " reached end of code",
					start,
					start + 1
				)
			end

			return false
		end,
	}
