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
		print = function(...)
			local str = {}

			for i = 1, select("#", ...) do
				local v = select(i, ...)
				str[i] = tostring(v)
			end

			str = table.concat(str, "\t") .. "\n"
			local info = debug.getinfo(2)

			if info and info.what ~= "C" then
				str = string.format("%s:%d: %s", info.short_src, info.currentline, str)
			end

			io.write(str)
		end
	end
end
