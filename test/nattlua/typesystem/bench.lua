do
	return
end

local Union = require("nattlua.types.union").Union
local LNumber = require("nattlua.types.number").LNumber
local profiler = require("nattlua.other.profiler")
local u = Union()
profiler.Start()

for i = 1, 10000 do
	u:AddType(LNumber(i))
end

profiler.Stop()
