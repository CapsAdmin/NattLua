-- This relies on lua's cached require. The table is filled with the string metatable in base_environment.lua

local Table = require("nattlua.types.table").Table
return Table()
