if _G.DISABLE_BASE_TYPES then
    return require("oh.typesystem.types").Table({})
end

local oh = require("oh")
local code_data = oh.File("oh/lua/base_typesystem.oh")

assert(code_data:Lex())
assert(code_data:Parse())

code_data:SetDefaultEnvironment(false)

local base = code_data.Analyzer()
assert(code_data:Analyze(base))

local g = code_data.SyntaxTree.environments.typesystem

require("oh.lua.string_meta"):Set("__index", g:Get("string"))

g:Set("_G", g)

return g