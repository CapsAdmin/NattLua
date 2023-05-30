#!/usr/local/bin/luajit

if not table.unpack and _G.unpack then table.unpack = _G.unpack end

if not io or not io.write then
	io = io or {}

	if _G.gmod then
		io.write = function(...)
			for i = 1, select("#", ...) do
				MsgC(Color(255, 255, 255), select(i, ...))
			end
		end
	else
		io.write = print
	end
end

do -- these are just helpers for print debugging
	table.print = require("nattlua.other.table_print")
	debug.trace = function(...)
		local level = 1

		while true do
			local info = debug.getinfo(level, "Sln")

			if (not info) then break end

			if (info.what) == "C" then
				io.write(string.format("\t%i: C function\t\"%s\"\n", level, info.name))
			else
				io.write(
					string.format("\t%i: \"%s\"\t%s:%d\n", level, info.name, info.short_src, info.currentline)
				)
			end

			level = level + 1
		end

		io.write("\n")
	end
-- local old = print; function print(...) old(debug.traceback()) end
end

require("nattlua.other.jit_options")()
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