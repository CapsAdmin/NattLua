#!/usr/local/bin/luajit

require("nattlua.other.lua_compat")
require("nattlua.other.jit_options").SetOptimized()
local m = require("nattlua.init")
package.loaded.nattlua = m

if _G.gmod then
	local pairs = pairs
	local getfenv = getfenv
	module("nattlua")
	local _G = getfenv(1)

	for k, v in pairs(m) do
		_G[k] = v
	end
end

local ARGS = _G.ARGS or {...}

if ARGS[1] and ARGS[1] ~= "nattlua" and ARGS[1] ~= "temp_build_output" then
	require("nattlua.cli")
	_G.RUN_CLI(unpack(ARGS))
end

return m