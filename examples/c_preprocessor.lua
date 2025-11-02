local preprocess = require("nattlua.definitions.lua.ffi.preprocessor.preprocessor")
local Lexer = require("nattlua.lexer.lexer").New
local Parser = require("nattlua.definitions.lua.ffi.parser").New
local Code = require("nattlua.code").New
local Compiler = require("nattlua.compiler")
local c_code = preprocess(
	[[#include <vulkan/vulkan.h>]],
	{
		working_directory = "/Users/caps/github/ffibuild/vulkan/repo/include",
		system_include_paths = {"/Users/caps/github/ffibuild/vulkan/repo/include"},
		defines = {
			VK_USE_PLATFORM_WAYLAND_KHR = 1,
			VK_USE_PLATFORM_XCB_KHR = 1,
			VK_USE_PLATFORM_XLIB_KHR = 1,
		},
		on_include = function(filename, full_path)
			print(string.format("Including: %s", filename))
		end,
	}
)
local f = io.open("nattlua_c_preprocessor_output.h", "w")
f:write(c_code)
f:close()

do
	return
end

local code = Code(c_code, "test.c")
local lex = Lexer(code)
local tokens = lex:GetTokens()
local parser = Parser(tokens, code)
parser.OnError = function(parser, code, msg, start, stop, ...)
	Compiler.OnDiagnostic({}, code, msg, "error", start, stop, nil, ...)
end
parser.CDECL_PARSING_MODE = "cdef"
local ast = parser:ParseRootNode()
local emitter = Emitter({skip_translation = true})
local res = emitter:BuildCode(ast)
