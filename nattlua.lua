if not table.unpack and _G.unpack then
	table.unpack = _G.unpack
end

do -- these are just helpers for print debugging
	table.print = require("nattlua.other.table_print")
	debug.trace = function(...) print(debug.traceback(...)) end
	--local old = print; function print(...) old(debug.traceback()) end
end

local helpers = require("nattlua.other.helpers")
helpers.JITOptimize()
--helpers.EnableJITDumper()

local loadstring = loadstring or load

local nl = {}

nl.Compiler = require("nattlua.compiler")

function nl.load(code, name, config)
	local obj = nl.Compiler(code, name, config)
	local code, err = obj:Emit()
	if not code then return nil, err end
    return loadstring(code, name)
end

function nl.loadfile(path, config)
	local obj = nl.File(path, config)
	local code, err = obj:Emit()
	if not code then return nil, err end
    return loadstring(code, path)
end

function nl.ParseFile(path, root)
	local code = assert(nl.File(path, {path = path, root = root}))
	return assert(code:Parse()), code
end

function nl.File(path, config)
	config = config or {}
	
	config.path = config.path or path
	config.name = config.name or path

	local f, err = io.open(path, "rb")
	if not f then
		return nil, err
	end
	local code = f:read("*all")
	f:close()
	return nl.Compiler(code, "@" .. path, config)
end

return nl