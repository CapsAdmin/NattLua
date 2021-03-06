local nl = require("nattlua")

local builder = assert(nl.File("example_project/src/main.nlua"))

function builder:OnResolvePath(path)
    return "example_project/src/" .. path
end

assert(builder:Lex())
assert(builder:Parse())

builder:Analyze()

local code, err = builder:Emit()

local file = io.open("example_project/out.lua", "w")
file:write(code)
file:close()

require("example_project.out")