local nl = require("nattlua")

local compiler = assert(
	nl.File(
		"src/main.nlua",
		{
			working_directory = "src/",
			inline_require = true,
		}
	)
)

local code = compiler:Emit(
	{
		preserve_whitespace = false,
		string_quote = "\"",
		no_semicolon = true,
		omit_invalid_code = true,
		comment_type_annotations = true,
		type_annotations = true,
		force_parenthesis = true,
		extra_indent = {
			Start = { to = "Stop" },
			Toggle = "toggle",
		},
	}
)
local f = assert(io.open("dist/main.lua", "w"))
f:write(code)
f:close()

-- analyze after file write so hotreload is faster
compiler:Analyze()
