--[[HOTRELOAD
	run_lua("test/tests/nattlua/c_declarations/preprocessor.lua")
]]
local Lexer = require("nattlua.definitions.lua.ffi.preprocessor.lexer").New
local Parser = require("nattlua.definitions.lua.ffi.preprocessor.parser").New
local Code = require("nattlua.code").New
-- Main preprocessor function with options support
return function(code, config)
	local code_obj = Code(code, "cpreprocessor")
	local tokens = Lexer(code_obj):GetTokens()
	local parser = Parser(tokens, code_obj, config)
	parser:Parse()
	return parser:ToString()
end
