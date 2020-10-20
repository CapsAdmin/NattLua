if _G.DISABLE_BASE_TYPES then
    return require("nattlua.typesystem.types").Table({})
end

local nl = require("nl")
local code_data = assert(nl.File("nattlua/lua/base_typesystem.nl"))

assert(code_data:Lex())
assert(code_data:Parse())

code_data:SetDefaultEnvironment(false)

local base = code_data.Analyzer()
assert(code_data:Analyze(base))

local g = code_data.SyntaxTree.environments.typesystem

require("nattlua.lua.string_meta"):Set("__index", g:Get("string"))

g:Set("_G", g)

return g