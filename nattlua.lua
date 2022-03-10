if not table.unpack and _G.unpack then table.unpack = _G.unpack end

if not _G.loadstring and _G.load then _G.loadstring = _G.load end

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
return require("nattlua.init")
