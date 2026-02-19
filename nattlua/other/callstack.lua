--ANALYZE
local callstack = {}
local debug = _G.debug
local ok, prof = pcall(require, "jit.profile")
local NATTLUA_MARKDOWN_OUTPUT = _G.NATTLUA_MARKDOWN_OUTPUT
if ok--[[# as boolean]] then
	function callstack.traceback(msg--[[#: string | nil]], level--[[#: 1 .. inf | nil]])
		level = level or 50
		msg = msg or "stack traceback:\n"
		local out = msg .. prof.dumpstack("pl\n", level + 2)

		if NATTLUA_MARKDOWN_OUTPUT then
			out = out:gsub("([%w%._%-%/]+):(%d+)", function(path, line)
				if path:find("/") or path:find("%.lua") or path:find("%.nlua") then
					return "[" .. path .. ":" .. line .. "](" .. path .. "#L" .. line .. ")"
				end
			end)
		end

		return out
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
		local out = debug.traceback()

		if NATTLUA_MARKDOWN_OUTPUT then
			out = out:gsub("([%w%._%-%/]+):(%d+)", function(path, line)
				if (path:find("/") or path:find("%.lua") or path:find("%.nlua")) and not path:find("%[") then
					return "[" .. path .. ":" .. line .. "](" .. path .. "#L" .. line .. ")"
				end
			end)
		end

		return out
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
