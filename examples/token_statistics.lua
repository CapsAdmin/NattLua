local nl = require("nattlua")
local util = require("examples.util")
local code = nl.Compiler(
	util.Get10MBLua(),
	"10mb.lua"
)
local tokens = assert(code:Lex())

util.CountFields(tokens.Tokens, "token types", function(a)
	return a.type
end, 30)
