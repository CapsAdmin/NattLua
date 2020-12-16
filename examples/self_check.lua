local nl = require("nattlua")

local c = assert(nl.File("./nattlua/syntax/syntax.lua"))
c.debug = true
c:EnableEventDump(true)
assert(c:Analyze())