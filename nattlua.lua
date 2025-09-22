#!/usr/bin/env luajit

if select(1, ...) == "profile" and select(2, ...) ~= "trace" then
	_G.REUSE_BASE_ENV = true
	local profiler = require("test.helpers.profiler")
	profiler.Start(select(2, ...))
	profiler.StartSection("startup")
	_G.STARTUP_PROFILE = true
elseif select(1, ...) == "test" then
	_G.REUSE_BASE_ENV = true
	local profiler = require("test.helpers.profiler")
	profiler.StartSection("startup")
	_G.STARTUP_PROFILE = true
end

if jit then
	if not package.searchpath("nattlua.cli.init", package.path) then
		local current_path
		local ffi = require("ffi")

		if jit.os ~= "Windows" then
			ffi.cdef("char *getcwd(char *buf, size_t size);")
			local buf = ffi.new("uint8_t[256]")
			ffi.C.getcwd(buf, 256)
			current_path = ffi.string(buf)
		else
			ffi.cdef("unsigned long GetCurrentDirectoryA(unsigned long length, char *buffer);")
			local buf = ffi.new("uint8_t[256]")
			ffi.C.GetCurrentDirectoryA(256, buf)
			current_path = ffi.string(buf):gsub("\\", "/")
		end

		local nattlua_path = debug.getinfo(1, "S").source:match("^@(.+)$")
		nattlua_path = nattlua_path:match("(.+)/nattlua%.lua$")
		local dir = current_path .. "/" .. nattlua_path .. "/"
		_G.ROOT_PATH = dir
		package.path = package.path .. ";" .. dir .. "?.lua" .. ";" .. dir .. "?/init.lua"
	end
end

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
	require("nattlua.cli.init").main(table.unpack(ARGS))
end

return m
