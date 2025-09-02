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
		max_level = max_level or math.huge
		local level = 1

		while level <= max_level do
			local info = debug.getinfo(level + 1, "Sln")

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
			local info = debug.getinfo(2)

			if info and info.short_src and (info.short_src:find("table_print") or info.short_src:find("lua_compat")) then
				info = debug.getinfo(3)
			end

			if info and info.what ~= "C" then
				str = string.format("%s:%d: %s", info.short_src, info.currentline, str)
			end

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
