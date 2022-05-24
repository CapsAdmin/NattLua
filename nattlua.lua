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

local ARGS = _G.ARGS or {...}
local cmd = ARGS[1]

if cmd == "run" then
	local path = assert(unpack(ARGS, 2))
	local compiler = assert(m.File(path))
	compiler:Analyze()
	assert(loadstring(compiler:Emit(), "@" .. path))(unpack(ARGS, 3))
elseif cmd == "check" then
	local path = assert(unpack(ARGS, 2))
	local compiler = assert(m.File(path))
	assert(compiler:Analyze())
elseif cmd == "build" then
	if unpack(ARGS, 2) then
		local path_from = assert(unpack(ARGS, 2))
		local compiler = assert(m.File(path_from))

		local path_to = assert(unpack(ARGS, 3))
		local f = assert(io.open(path_to, "w"))
		f:write(compiler:Emit())
		f:close()
	else
		if _G.IMPORTS then
			for k,v in pairs(IMPORTS) do
				if not k:find("/") then
					package.preload[k] = v
				end
			end
			package.preload.nattlua = package.preload["nattlua.init"]
		end

		assert(_G["load".."file"]("./nlconfig.lua"))(unpack(ARGS))
	end
end

return m
