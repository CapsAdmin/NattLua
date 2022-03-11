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

function nl.ParseFile(path, config)
	config = config or {}
	local code, err = nl.File(path, config)

	if not code then return nil, err end

	local ok, err = code:Parse()

	if not ok then return nil, err end

	return ok, code
end

function nl.File(path, config)
	config = config or {}
	config.file_path = config.file_path or path
	config.file_name = config.file_name or path
	local f, err = io.open(path, "rb")

	if not f then return nil, err end

	local code = f:read("*all")
	f:close()

	if not code then return nil, path .. " empty file" end

	return nl.Compiler(code, "@" .. path, config)
end

return nl
