local nl = {}
local loadstring = require("nattlua.other.loadstring")
nl.Compiler = require("nattlua.compiler").New

function nl.load(code, name, config)
	config = config or {}
	config.file_name = config.file_name or name
	local obj = nl.Compiler(code, config.file_name, config)
	local code, err = obj:Emit()

	if not code then return nil, err end

	return loadstring(code, config.file_name)
end

function nl.loadfile(path, config)
	local obj = nl.File(path, config)
	local code, err = obj:Emit()

	if not code then return nil, err end

	return loadstring(code, obj.config.file_name)
end

function nl.File(path, config)
	config = config or {}
	config.file_path = config.file_path or path
	config.file_name = config.file_name or "@" .. path
	local f, err = io.open(path, "rb")

	if not f then return nil, err end

	local code = f:read("*all")
	f:close()

	if not code then return nil, path .. " empty file" end

	return nl.Compiler(code, config.file_name, config)
end

return nl