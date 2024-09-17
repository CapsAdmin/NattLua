local stringx = require("nattlua.other.string")
local path = {}

function path.RemoveProtocol(str--[[#: string]])
	return (string.gsub(str, "^.+://", ""))
end

function path.RemoveFilename(str--[[#: string]])
	return (string.match(str, "^(.+/)"))
end

function path.GetParentDirectory(str--[[#: string]], level--[[#: number]])
	level = level or 1
	str = path.RemoveFilename(str)

	for i = 1, level do
		str = str:match("(.+/)")
	end

	return str
end

function path.WalkParentDirectory(str--[[#: string]])
	local i = 1
	return function()
		local dir = path.GetParentDirectory(str, i)
		i = i + 1
		return dir
	end
end

function path.Normalize(str--[[#: string]])
	str = stringx.replace(str, "\\", "/") 
	str = stringx.replace(str, "/../", "/")
	str = stringx.replace(str, "/./", "/")

	while true do
		local new = stringx.replace(str, "//", "/")
		if new == str then break end
		str = new
	end

	if str:sub(1, 2) == "./" then str = str:sub(3) end

	return str
end

local function exists(path)
	local f = io.open(path)

	if f then
		f:close()
		return true
	end

	return false
end

local ok, fs = pcall(require, "nattlua.other.fs")

if ok then exists = function(path)
	return fs.get_type(path) == "file"
end end

path.Exists = exists

local function directory_from_path(path)
	for i = #path, 1, -1 do
		if path:sub(i, i) == "/" then return path:sub(1, i) end
	end

	return nil
end

function path.Resolve(path, root_directory, working_directory, file_path)
	root_directory = root_directory or ""
	working_directory = working_directory or ""

	if path:sub(1, 1) == "/" then
		return path
	elseif path:sub(1, 1) == "~" then
		path = path:sub(2)

		if path:sub(1, 1) == "/" then path = path:sub(2) end

		return root_directory .. working_directory .. path
	else
		if path:sub(1, 2) == "./" then path = path:sub(3) end

		do
			working_directory = file_path and directory_from_path(file_path) or working_directory

			if exists(working_directory .. path) then
				return working_directory .. path
			else
				if working_directory then
					if exists(root_directory .. working_directory .. path) then
						return root_directory .. working_directory .. path
					end
				end

				return root_directory .. path
			end
		end
	end

	return path
end

function path.ResolveRequire(str)
	local paths = package.path .. ";"
	paths = paths .. "./?/init.lua;"
	require_path = stringx.replace(str, ".", "/")

	for _, package_path in ipairs(stringx.split(paths, ";")) do
		local lua_path = stringx.replace(package_path, "?", require_path)

		if exists(lua_path) then return lua_path end
	end

	return nil
end

return path