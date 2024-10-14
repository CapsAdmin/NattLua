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
end
