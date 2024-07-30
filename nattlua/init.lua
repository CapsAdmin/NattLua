local Compiler = require("nattlua.compiler")

local nl = {}

nl.Compiler = Compiler.New
nl.load = Compiler.Load
nl.loadfile = Compiler.LoadFile
nl.File = Compiler.FromFile

return nl