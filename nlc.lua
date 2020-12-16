#!/usr/local/bin/luajit
local nl = require("nattlua")
local path = ...

local c = assert(nl.File(path))
assert(c:Analyze())