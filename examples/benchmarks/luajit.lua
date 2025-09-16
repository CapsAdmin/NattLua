local nl = require("nattlua")
local util = require("examples.util")
local lua_code = util.Get10MBLua()
local load = loadstring or load

util.Measure("load(lua_code)", function()
	return assert(load(lua_code))
end)
