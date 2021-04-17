-- This relies on lua's cached require. The table is filled with the string metatable in base_environment.lua

local types = require("nattlua.types.types")
return types.Table()
