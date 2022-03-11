local nl = require("nattlua")
local builder = assert(
	nl.File(
		"examples/projects/luajit/src/main.nlua",
		{
			working_directory = "examples/projects/luajit/src/",
			emit_environment = true,
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
		use_comment_types = true,
		annotate = false,
		force_parenthesis = true,
		extra_indent = {
			Start = {to = "Stop"},
			Toggle = "toggle",
		},
	}
)
print("===RUNNING CODE===")
require("examples/projects.luajit.out")
