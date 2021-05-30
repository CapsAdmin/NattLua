--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local string = require("string")
return
	{
		ReadMultilineComment = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if
				lexer:IsValue("-", 0) and
				lexer:IsValue("-", 1) and
				lexer:IsValue("[", 2) and
				(lexer:IsValue("[", 3) or lexer:IsValue("=", 3))
			then
				local start = lexer:GetPosition()
				lexer:Advance(3)

				if lexer:IsCurrentValue("=") then
					while not lexer:TheEnd() do
						lexer:Advance(1)
						if not lexer:IsCurrentValue("=") then break end
					end
				end

				if not lexer:IsCurrentValue("[") then
					lexer:SetPosition(start)
					return false
				end

				lexer:Advance(1)
				local pos = lexer:FindNearest("]" .. string.rep("=", (lexer:GetPosition() - start) - 4) .. "]")

				if pos then
					lexer:SetPosition(pos)
					return "multiline_comment"
				end

				lexer:Error("expected multiline comment to end, reached end of code", start, start + 1)
				lexer:SetPosition(start + 2)
			end

			return false
		end,
	}
