local callstack = require("nattlua.other.callstack")

if not _G.jit and _G._VERSION == "Lua 5.1" then
	local old = xpcall
	xpcall = function(f, errcb, ...)
		local args = {...}
		return old(function()
			return f(unpack(args))
		end, errcb)
	end
end

if not table.unpack and _G.unpack then table.unpack = _G.unpack end

-- gmod
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

_G.bit = _G.bit or require("nattlua.other.bit")

do -- these are just helpers for print debugging
	table.print = require("nattlua.other.table_print").print
	debug.trace = function(max_level)
		io.write(callstack.traceback(max_level))
	end

	do
		local old = print
		local context = require("nattlua.analyzer.context")
		print = function(...)
			local str = {}

			for i = 1, select("#", ...) do
				local v = select(i, ...)
				str[i] = tostring(v)
			end

			str = table.concat(str, "\t") .. "\n"
			local path = callstack.get_line(2)

			if
				path and
				(
					path:find("table_print") or
					path:find("lua_compat")
				)
			then
				path = callstack.get_line(3)
			end

			if path then str = string.format("%s %s", path, str) end

			do -- dim the color if the print comes from the base environment as we're likely not print debugging that
				local a = context:GetCurrentAnalyzer()

				if a and a.compiler and a.compiler.is_base_environment then
					str = require("nattlua.cli.colors").dim(str)
				end
			end

			io.write(str)
		end
	end

	do
		local old = print
		local done = {}

		function print_once(...)
			local tbl = {}

			for i = 1, select("#", ...) do
				tbl[i] = tostring((select(i, ...)))
			end

			local hash = table.concat(tbl, "\t")

			if not done[hash] then
				old(hash)
				done[hash] = true
			end
		end
	end
end
