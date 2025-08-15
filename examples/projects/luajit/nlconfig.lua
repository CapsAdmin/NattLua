local args = ...
local config = {commands = {}}
config.commands["build"] = {
	cb = function()
		local nl = require("nattlua")
		local builder = assert(
			nl.File(
				"src/main.nlua",
				{
					parser = {
						working_directory = "src/",
						emit_environment = false,
					},
				}
			)
		)
		assert(builder:Lex())
		assert(builder:Parse())
		assert(builder:Analyze())
		local code, err = builder:Emit(
			{
				preserve_whitespace = false,
				string_quote = "\"",
				no_semicolon = true,
				omit_invalid_code = true,
				comment_type_annotations = true,
				type_annotations = false,
				force_parenthesis = true,
				extra_indent = {
					Start = {to = "Stop"},
					Toggle = "toggle",
				},
			}
		)
		local file = assert(io.open("out.lua", "w"))
		file:write(code)
		file:close()
		print("===RUNNING CODE===")
		require("out")
	end,
}
config.commands["get-compiler-config"] = {
	cb = function()
		return {
			lsp = {entry_point = "main.nlua"},
			parser = {working_directory = "src/", emit_environment = false},
			analyzer = {working_directory = "src/"},
		}
	end,
}
return config
