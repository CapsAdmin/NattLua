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

return path