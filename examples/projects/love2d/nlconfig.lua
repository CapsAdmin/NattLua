local nl = require("nattlua")
--require("examples.projects.love2d.build_love_api")
local working_directory = "examples/projects/love2d/"
local compiler = assert(
	nl.File(
		working_directory .. "game/main.nlua",
		{
			working_directory = working_directory,
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
			Start = {to = "Stop"},
			Toggle = "toggle",
		},
	}
)
local f = assert(io.open(working_directory .. "out/main.lua", "w"))
f:write(code)
f:close()

-- parse afterwards so hotreload is faster
compiler:Analyze()
--os.execute("love " .. working_directory .. "out/")
