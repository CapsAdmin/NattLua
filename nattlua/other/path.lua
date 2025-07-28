local stringx = require("nattlua.other.string")
local path = {}

function path.RemoveProtocol(str--[[#: string]])
	return (string.gsub(str, "^.+://", ""))
end

function path.UrlSchemeToPath(url, wdir)
	url = path.RemoveProtocol(url)

	if url:sub(1, 1) ~= "/" then
		local start, stop = url:find(wdir, 1, true)

		if start == 1 and stop then url = url:sub(stop + 1, #url) end

		if url:sub(1, #wdir) ~= wdir then
			if wdir:sub(#wdir) ~= "/" then
				if url:sub(1, 1) ~= "/" then url = "/" .. url end
			end

			url = wdir .. url
		end
	end

	url = path.Normalize(url)
	return url
end

function path.PathToUrlScheme(path)
	if path:sub(1, 1) == "@" then path = path:sub(2) end

	if path:sub(1, 7) ~= "file://" then path = "file://" .. path end

	return path
end

function path.Normalize(str--[[#: string]])
	str = stringx.replace(str, "\\", "/")
	str = stringx.replace(str, "/./", "/")

	while true do
		local new = stringx.replace(str, "//", "/")

		if new == str then break end

		str = new
	end

	local new = {}

	for i, v in ipairs(stringx.split(str, "/")) do
		if v == ".." then new[#new] = nil else new[#new + 1] = v end
	end

	str = table.concat(new, "/")

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

if ok and fs.get_type then
	exists = function(path)
		return fs.get_type(path) == "file"
	end
end

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

function path.Join(...)
	local segments = {...}
	local result = ""

	for i, segment in ipairs(segments) do
		if i > 1 and result:sub(-1) ~= "/" and segment:sub(1, 1) ~= "/" then
			result = result .. "/"
		end

		result = result .. segment
	end

	return path.Normalize(result)
end

function path.GetDirectory(path)
	local last_slash = path:find("/[^/]*$")

	if last_slash then return path:sub(1, last_slash - 1) else return "" end
end

function path.GetFileName(path, no_extension)
	local last_slash = path:find("/[^/]*$")

	if last_slash then path = path:sub(last_slash + 1) else path = path end

	if no_extension then
		local last_dot = path:find("%.[^%.]*$")

		if last_dot then return path:sub(1, last_dot - 1) else return path end
	end

	return path
end

return path
