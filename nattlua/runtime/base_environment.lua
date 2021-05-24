if _G.DISABLE_BASE_ENV then return require("nattlua.types.types").Table({}) end
local nl = require("nattlua")
local compiler = assert(nl.File("nattlua/definitions/index.nlua"))
assert(compiler:Lex())
assert(compiler:Parse())
compiler:SetDefaultEnvironment(false)
local base = compiler.Analyzer()
assert(compiler:Analyze(base))
local g = compiler.SyntaxTree.environments.typesystem
require("nattlua.runtime.string_meta"):Set("__index", g:Get("string"))
g:Set("_G", g)
return g
