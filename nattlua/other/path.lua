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
	str = string.gsub(str, "\\", "/")
	str = string.gsub(str, "/+", "/")
	str = str:gsub("/%./", "/")

	while true do
		local found, count = str:gsub("[^/]+/%.%./", "")

		if count == 0 then break end

		str = found
	end

	if str:sub(1, 2) == "./" then str = str:sub(3) end

	return str
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
			working_directory = file_path and
				file_path:match("(.+/)") or
				working_directory
			local f = io.open(working_directory .. path)

			if f then
				f:close()
				return working_directory .. path
			else
				return root_directory .. path
			end
		end
	end
	
	return path
end

return path