local oh = require("oh")
local code_data = oh.File("oh/lua/base_typesystem.oh")

assert(code_data:Lex())
assert(code_data:Parse())

local base = code_data.Analyzer()
base.IndexNotFound = nil

assert(code_data:Analyze(nil, base))

local g = base:TypeFromImplicitNode(code_data.SyntaxTree, "table")

for k, v in pairs(base.env.typesystem) do
    g:Set(k, v)
end

g:Set("_G", g)

require("oh.lua.string_meta"):Set("__index", g:Get("string"))

base:SetValue("_G", g, "typesystem")

return base