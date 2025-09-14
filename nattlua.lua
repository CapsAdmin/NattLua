#!/usr/bin/env luajit

if false then
	debug.sethook(
		function()
			if os.clock() > 10 then
				debug.trace()
				error("timeout")
			end
		end,
		"c"
	)
end

if false then
	local _G = _G
	local blacklist = {_G = true, require = true, analyze = true, equal = true}
	local debug = _G.debug
	local io_write = _G.io.write
	local debug_trace = debug.traceback

	local function get_line()
		local info = debug.getinfo(3)

		if not info then return "**unknown line**" end

		if info.source:sub(1, 1) == "@" then
			return info.source:sub(2) .. ":" .. info.currentline
		end

		return info.source .. ":" .. info.currentline
	end

	local done = {}
	setfenv(
		0,
		setmetatable(
			{},
			{
				__index = function(_, k)
					if k == "x" then io_write(debug_trace(), "\n") end

					if not blacklist[k] then
						local str = k .. " GET " .. get_line() .. "\n"

						if not done[str] and not str:find("tests/", nil, true) then
							io_write(str)
						end
					end

					return _G[k]
				end,
				__newindex = function(_, k, v)
					if not blacklist[k] then
						local str = k .. " SET " .. get_line() .. "\n"

						if not done[str] and not str:find("tests/", nil, true) then
							io_write(str)
						end
					end

					_G[k] = v
				end,
			}
		)
	)
end

if jit then
	local ok, err = pcall(require, "nattlua.cli.init")
	print(err)

	if not ok then
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

if ... == "test" then
	require("test.helpers.preprocess")
	STARTUP_PROFILE = true
	require("test.helpers.profiler").Start()
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
