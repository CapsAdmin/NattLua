local Lexer = require("nattlua.lexer.lexer").New
-- just reuse the lua lexer
return (
	{
		New = function(code)
			local lexer = Lexer(code)
			lexer.ReadShebang = function()
				return false
			end
			return lexer
		end,
	}
)
