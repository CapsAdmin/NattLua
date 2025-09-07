local get_time = require("test.helpers.get_time")
local util = {}

function util.GetFilesRecursively(dir, ext)
	ext = ext or ".lua"
	local f = assert(io.popen("find " .. dir))
	local lines = f:read("*all")
	local paths = {}

	for line in lines:gmatch("(.-)\n") do
		if line:sub(-#ext) == ext then table.insert(paths, line) end
	end

	return paths
end

function util.FetchCode(path--[[#: string]], url--[[#: string]]) --: type util.FetchCode = function(string, string): string
	local f = io.open(path, "rb")

	if not f then
		os.execute("wget --force-directories -O " .. path .. " " .. url)
		f = io.open(path, "rb")

		if not f then
			os.execute("curl  " .. url .. " --create-dirs --output " .. path)
		end

		if not io.open(path, "rb") then error("unable to download file?") end
	end

	f = assert(io.open(path, "rb"))
	local code = f:read("*all")
	f:close()
	return code
end

do
	local indent = 0

	local function dump(tbl, blacklist, done)
		for k, v in pairs(tbl) do
			if (not blacklist or blacklist[k] ~= type(v)) and type(v) ~= "table" then
				io.write(("\t"):rep(indent))
				local v = v

				if type(v) == "string" then v = "\"" .. v .. "\"" end

				io.write(tostring(k), " = ", tostring(v), "\n")
			end
		end

		for k, v in pairs(tbl) do
			if (not blacklist or blacklist[k] ~= type(v)) and type(v) == "table" then
				if done[v] then
					io.write(("\t"):rep(indent))
					io.write(tostring(k), ": CIRCULAR\n")
				else
					io.write(("\t"):rep(indent))
					io.write(tostring(k), ":\n")
					indent = indent + 1
					done[v] = true
					dump(v, blacklist, done)
					indent = indent - 1
				end
			end
		end
	end

	function util.TablePrint(tbl--[[#: {[any] = any}]], blacklist--[[#: {[string] = string}]])
		dump(tbl, blacklist, {})
	end
end

function util.CountFields(tbl, what, cb, max)
	max = max or 10
	local score = {}

	for _, v in ipairs(tbl) do
		local key = cb(v)
		score[key] = (score[key] or 0) + 1
	end

	local temp = {}

	for k, v in pairs(score) do
		table.insert(temp, {name = k, score = v})
	end

	table.sort(temp, function(a, b)
		return a.score > b.score
	end)

	io.write("top " .. max .. " ", what, ":\n")

	for i = 1, max do
		local data = temp[i]

		if not data then break end

		if i < max then io.write(" ") end

		io.write(i, ": `", data.name, "´ occured ", data.score, " times\n")
	end
end

local function get_median(tbl, start, stop)
	start = start or 1
	stop = stop or #tbl
	local new = {}

	for i = start, stop do
		table.insert(new, tbl[i])
	end

	table.sort(new)
	local median = new[math.ceil(#new / 2)] or new[1]
	return median
end

local function get_average(tbl, start, stop)
	start = start or 1
	stop = stop or #tbl

	if #tbl == 0 then return nil end

	local n = 0
	local count = 0

	for i = start, stop do
		n = n + tbl[i]
		count = count + 1
	end

	return n / count
end

function util.Measure(what, cb) -- type util.Measure = function(string, function): any
	local space = (" "):rep(40 - #what)
	io.write("> ", what, "\n")
	local times = {}
	local threshold = 0.01
	local lookback = 5
	local total_time = 0

	for i = 1, 30 do
		local time = get_time()
		local ok, err = pcall(cb)
		times[i] = get_time() - time
		total_time = total_time + times[i]
		io.write(("%.5f"):format(times[i]), " seconds\n")

		if i >= lookback and times[i] > 0.5 then
			local current = get_average(times)
			local latest = get_average(times, #times - lookback + 1)
			local diff = math.abs(current - latest)

			if diff > 0 and diff < threshold then
				io.write(
					"time difference the last ",
					lookback,
					" times (",
					diff,
					") met the threshold (",
					threshold,
					"), stopped measuring.\n"
				)

				break
			end

			if total_time > 10 and #times > 5 then
				io.write("total time exceeded 10 seconds after 5 attempts, stopped measuring.\n")

				break
			end
		end

		if not ok then
			io.write(" - FAIL: ", err)
			error(err, 2)
		end
	end

	local average = get_average(times)
	local median = get_median(times)
	table.sort(times)
	local min = times[1]
	local max = times[#times]
	io.write(
		"< FINISHED: ",
		("%.5f"):format(median),
		" seconds (median), ",
		("%.5f"):format(average),
		" seconds (average)\n"
	)
end

function util.MeasureFunction(cb)
	local start = get_time()
	cb()
	return get_time() - start
end

function util.LoadGithub(url, path)
	os.execute("mkdir -p examples/benchmarks/temp/")
	local full_path = "examples/benchmarks/temp/" .. path .. ".lua"
	local code = assert(util.FetchCode(full_path, "https://raw.githubusercontent.com/" .. url))
	package.loaded[path] = assert(load(code, "@" .. full_path))()
	return package.loaded[path]
end

return util
