local nl = require("nattlua")
local builder = assert(nl.File("example_projects/luajit/src/test.nlua"))

function builder:OnResolvePath(path)
	return "example_projects/luajit/src/" .. path
end

assert(builder:Lex())
assert(builder:Parse())
assert(builder:Analyze())
