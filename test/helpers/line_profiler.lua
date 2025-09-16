--[[HOTRELOAD 
    run_lua("test/performance/lexer.lua")
]]
local preprocess = require("test.helpers.preprocess")
local line_hook = require("test.helpers.line_hook")
local get_time = require("test.helpers.get_time")
local formating = require("nattlua.other.formating")
local colors = require("nattlua.cli.colors")
local line_profiler = {}

-- this must be called before loading modules
function line_profiler.Start(whitelist)
	whitelist = whitelist or {"^nattlua/"}

	local function matches_whitelist(path)
		for _, pattern in ipairs(whitelist) do
			if path:find(pattern) then return true end
		end

		return false
	end

	local table_new = require("nattlua.other.tablex").new
	local lines = table_new(0, 100)

	function _G.LINE_OPEN(path, start_stop)
		lines[path] = lines[path] or table_new(0, 500)
		lines[path][start_stop] = lines[path][start_stop] or table_new(0, 2)
		lines[path][start_stop].start_time = get_time()
	end

	function _G.LINE_CLOSE(path, start_stop)
		local line = lines[path][start_stop]
		line.time = (line.time or 0) + get_time() - line.start_time
	end

	function preprocess.Preprocess(code, name, path, from)
		if from == "package" then
			if path and matches_whitelist(path) then
				io.write("profiling " .. path .. "\n")
				local code = line_hook.Preprocess(code, name, path, from)
				return code
			end
		end

		return code
	end

	local dispose = preprocess.Init(
		(
			function()
				local tbl = {}

				for k, v in pairs(package.loaded) do
					if k:find("preprocess") or k:find("line_hook") then

					else
						if k:find("nattlua") or k:find("test%.") then
							table.insert(tbl, k)
							io.write("unloading " .. k .. "\n")
						end
					end
				end

				return tbl
			end
		)()
	)
	return function()
		dispose()
		_G.LINE_OPEN = nil
		_G.LINE_CLOSE = nil
		local files = lines

		for path, lines in pairs(lines) do
			local fixed = {}

			for start_stop, data in pairs(lines) do
				local line = {}
				line.time = data.time or 0
				line.path = path
				local s, e = start_stop:match("^(%d+)_(%d+)$")
				line.start = tonumber(s)
				line.stop = tonumber(e)
				table.insert(fixed, line)
			end

			files[path] = fixed
		end

		local sorted_files = {}

		for path, lines in pairs(files) do
			local f = assert(io.open(path, "r"))
			local lua = f:read("*a")
			f:close()
			local total = 0

			for _, line in ipairs(lines) do
				local info = formating.SubPosToLineCharCached(lua, line.start, line.stop)
				line.path_line = line.path .. ":" .. info.line_start .. ":" .. info.character_start
				total = total + line.time
			end

			table.sort(lines, function(a, b)
				return a.time < b.time
			end)

			table.insert(sorted_files, {
				path = path,
				lines = lines,
				total = total,
			})
		end

		table.sort(sorted_files, function(a, b)
			return a.total < b.total
		end)

		local str = {}

		local function format_time(seconds)
			if seconds > 1 then
				return string.format("%.2fs", seconds)
			elseif seconds > 0.01 then
				return string.format("%.1fms", seconds * 1000)
			end

			return string.format("%.0fus", seconds * 1000000)
		end

		local function format(seconds)
			if seconds > 0.1 then
				return colors.red(format_time(seconds))
			elseif seconds > 0.01 then
				return colors.yellow(format_time(seconds))
			end

			return colors.green(format_time(seconds))
		end

		local function pad_right(str, len)
			while #str < len do
				str = str .. " "
			end

			return str
		end

		for _, file in ipairs(sorted_files) do
			local line_length = 0

			for _, line in ipairs(file.lines) do
				line_length = math.max(line_length, #line.path_line)
			end

			table.insert(str, pad_right(file.path, line_length + 1) .. " - " .. format(file.total))

			for _, line in ipairs(file.lines) do
				if line.time > 0.0001 then
					table.insert(
						str,
						" " .. pad_right(line.path_line, line_length) .. " - " .. format(line.time)
					)
				end
			end

			table.insert(str, pad_right(file.path, line_length + 1) .. " - " .. format(file.total))
			table.insert(str, "")
		end

		return table.concat(str, "\n")
	end
end

return line_profiler
