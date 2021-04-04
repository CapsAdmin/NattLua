local nl = require("nattlua")

local function GetFilesRecursively(dir, ext)
    ext = ext or ".lua"

    local f = assert(io.popen("find " .. dir))
    local lines = f:read("*all")
    local paths = {}
    for line in lines:gmatch("(.-)\n") do
        if line:sub(-4) == ext then
            table.insert(paths, line)
        end
    end
    return paths
end

local function read_file(path)
	local f = assert(io.open(path, "r"))
	local contents = f:read("*all")
	f:close()
	return contents
end

local function write_file(path, contents)
	local f = assert(io.open(path, "w"))
	f:write(contents)
	f:close()
end

local lua_files = GetFilesRecursively("./nattlua/", ".lua")

local config = {
	preserve_whitespace = false,
	string_quote = "\"",
	no_semicolon = true,
	use_comment_types = true,
	annotate = "explicit",
	force_parenthesis = true,
	extra_indent = {
		CreateAndPushScope = {
			to = "PopScope",
		},

		PushScope = {
			to = "PopScope",
		},
	}
}

for _, path in ipairs(lua_files) do
    local lua_code = read_file(path)
    local new_lua_code = assert(nl.Code(lua_code, "@" .. path, config)):Emit()
    if new_lua_code:sub(#new_lua_code, #new_lua_code) ~= "\n" then
        new_lua_code = new_lua_code .. "\n"
    end
    --assert(loadstring(new_lua_code, "@" .. path))
    write_file(path, new_lua_code)
end