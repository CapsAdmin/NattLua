--ANALYZE
local callstack = {}
local debug = _G.debug
local ok, prof = pcall(require, "jit.profile")

if ok--[[# as boolean]] then
	function callstack.traceback(level--[[#: 1 .. inf | nil]])
		level = level or 50
		return prof.dumpstack("pl\n", level + 2)
	end

	function callstack.get_line(level--[[#: 1 .. inf]])
		level = level + 2
		local str = prof.dumpstack("pl\n", level)--[[# as string]]
		local pos = 1

		for i = 1, level do
			local start, stop = str:find("\n", pos, true)

			if not start or not stop then break end

			if i == level then return str:sub(pos, start - 1) end

			pos = stop + 1
		end

		return nil
	end

	function callstack.get_path_line(level--[[#: 1 .. inf]])
		local line = callstack.get_line(level + 1)

		if not line then return nil end

		local colon = line:find(":", nil, true)

		if not colon then return line end

		return line:sub(1, colon - 1), line:sub(colon + 1), line
	end
else
	function callstack.traceback()
		return debug.traceback()
	end

	function callstack.get_line(level--[[#: 1 .. inf]])
		local info = debug.getinfo(level + 1, "Sl")

		if not info then return nil end

		return string.format("%s:%d", info.source, info.currentline)
	end

	function callstack.get_path_line(level--[[#: 1 .. inf]])
		local info = debug.getinfo(level + 1, "Sl")

		if not info then return nil end

		return info.source,
		tostring(info.currentline),
		info.source .. ":" .. tostring(info.currentline)
	end
end

local ok, util = pcall(require, "jit.util")

if ok--[[# as boolean]] then
	function callstack.get_func_path_line(func--[[#: AnyFunction]])
		local info = util.funcinfo(func)
		return info.source, info.linedefined
	end
else
	function callstack.get_func_path_line(func--[[#: AnyFunction]])
		local info = debug.getinfo(func, "Sl")

		if not info then return end

		return info.source, info.linedefined
	end
end

return callstack
