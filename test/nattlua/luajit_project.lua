local nl = require("nattlua")
local builder = assert(nl.File("examples/projects/luajit/src/test.nlua"))

function builder:OnResolvePath(path)
	return "examples/projects/luajit/src/" .. path
end

assert(builder:Lex())
assert(builder:Parse())
assert(builder:Analyze())
