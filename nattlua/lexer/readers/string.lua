--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

local read_space = require("nattlua.lexer.readers.space")
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
					read_space(lexer)
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
		read_double_quote = build_string_reader("double", "\""),
		read_single_quote = build_string_reader("single", "'"),
	}
