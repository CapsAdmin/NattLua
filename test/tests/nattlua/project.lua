 --PENDING_TEST
do
	return
end

local nl = require("nattlua")
local builder = assert(
	nl.File(
		"examples/projects/luajit/src/test.nlua",
		{
			parser = {working_directory = "examples/projects/luajit/src/"},
		}
	)
)
assert(builder:Lex())
assert(builder:Parse())
assert(builder:Analyze())
