--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local ReadSpace = require("nattlua.lexer.readers.space").ReadSpace
local B = string.byte
local escape_character = B([[\]])

local function build_string_reader(name--[[#: string]], quote--[[#: string]])
	return function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
		if not lexer:IsCurrentValue(quote) then return false end
		local start = lexer:GetPosition()
		lexer:Advance(1)

		while not lexer:TheEnd() do
			local char = lexer:ReadChar()

			if char == escape_character then
				local char = lexer:ReadChar()

				if char == B("z") and not lexer:IsCurrentValue(quote) then
					ReadSpace(lexer)
				end
			elseif char == B("\n") then
				lexer:Advance(-1)
				lexer:Error("expected " .. name:lower() .. " quote to end", start, lexer:GetPosition() - 1)
				return "string"
			elseif char == B(quote) then
				return "string"
			end
		end

		lexer:Error(
			"expected " .. name:lower() .. " quote to end: reached end of file",
			start,
			lexer:GetPosition() - 1
		)
		return "string"
	end
end

return
	{
		ReadDoubleQuoteString = build_string_reader("double", "\""),
		ReadSingleQuoteString = build_string_reader("single", "'"),
	}
