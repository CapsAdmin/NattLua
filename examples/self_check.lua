local nl = require("nattlua")

local c = assert(nl.File("./nattlua.lua"))
c:EnableEventDump(true)
assert(c:Analyze())