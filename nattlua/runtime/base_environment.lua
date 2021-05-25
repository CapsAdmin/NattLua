if _G.DISABLE_BASE_ENV then return require("nattlua.types.table").Table({}) end
local nl = require("nattlua")
local LString = require("nattlua.types.string").LString
local compiler = assert(nl.File("nattlua/definitions/index.nlua"))
assert(compiler:Lex())
assert(compiler:Parse())
compiler:SetDefaultEnvironment(false)
local base = compiler.Analyzer()
assert(compiler:Analyze(base))
local g = compiler.SyntaxTree.environments.typesystem
require("nattlua.runtime.string_meta"):Set(types.LString("__index"), g:Get(types.LString("string")))
g:Set(types.LString("_G"), g)
return g
