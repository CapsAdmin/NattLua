local nl = require("nattlua")
local builder = assert(nl.File("examples/projects/luajit/src/main.nlua"))

function builder:OnResolvePath(path)
	return "examples/projects/luajit/src/" .. path
end

assert(builder:Lex())
assert(builder:Parse())
assert(builder:Analyze())
local code, err = builder:Emit(
	{
		preserve_whitespace = false,
		string_quote = "\"",
		no_semicolon = true,
		use_comment_types = false,
		annotate = false,
		force_parenthesis = true,
		extra_indent = {
			Start = {to = "Stop"},
			Toggle = "toggle",
		},
	}
)
-- todo
code = io.open("nattlua/runtime/base_runtime.lua"):read("*all") .. "\n" .. code
local file = io.open("examples/projects/luajit/out.lua", "w")
file:write(code)
file:close()
print("===RUNNING CODE===")
require("examples/projects.luajit.out")
