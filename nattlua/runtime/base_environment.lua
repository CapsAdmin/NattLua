if _G.DISABLE_BASE_ENV then return require("nattlua.types.types").Table({}) end
local nl = require("nattlua")
local code_data = assert(nl.File("nattlua/runtime/base_environment.nlua"))
assert(code_data:Lex())
assert(code_data:Parse())
code_data:SetDefaultEnvironment(false)
local base = code_data.Analyzer()
assert(code_data:Analyze(base))
local g = code_data.SyntaxTree.environments.typesystem
require("nattlua.runtime.string_meta"):Set("__index", g:Get("string"))
g:Set("_G", g)
return g
