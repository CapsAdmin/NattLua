if not table.unpack and _G.unpack then table.unpack = _G.unpack end

if not io or not io.write then
	io = io or {}

	if gmod then
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
		print(debug.traceback(...))
	end
-- local old = print; function print(...) old(debug.traceback()) end
end

local helpers = require("nattlua.other.helpers")
helpers.JITOptimize()
--helpers.EnableJITDumper()
local m = require("nattlua.init")

if _G.gmod then
	local pairs = pairs
	local getfenv = getfenv
	module("nattlua")
	local _G = getfenv(1)

	for k, v in pairs(m) do
		_G[k] = v
	end
end

return m
