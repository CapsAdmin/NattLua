--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local string = require("string")
local ReadLineComment = require("nattlua.lexer.readers.line_comment").ReadLineComment
return
	{
		ReadMultilineComment = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if not lexer:IsString("--[") or (not lexer:IsString("[", 3) and not lexer:IsString("=", 3)) then
				return false
			end

			local start = lexer:GetPosition()

			-- skip past the --[
			lexer:Advance(3)

			while lexer:IsString("=") do
				lexer:Advance(1)
			end

			if not lexer:IsString("[") then
				-- if we have an incomplete multiline comment, it's just a single line comment
				lexer:SetPosition(start)
				return ReadLineComment(lexer);
			end

			-- skip the last [
			lexer:Advance(1)
			local pos = lexer:FindNearest("]" .. string.rep("=", (lexer:GetPosition() - start) - 4) .. "]")

			if pos then
				lexer:SetPosition(pos)
				return "multiline_comment"
			end

			lexer:Error("expected multiline comment to end, reached end of code", start, start + 1)
			lexer:SetPosition(start + 2)

			return false
		end,
	}
