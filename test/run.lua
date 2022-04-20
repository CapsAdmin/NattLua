local preprocess = require("nattlua.other.preprocess")
local coverage = require("nattlua.other.coverage")
local io = require("io")
local pcall = _G.pcall

--require("nattlua.other.helpers").GlobalLookup()
function _G.test(name, cb)
	cb()
end

function _G.pending() end

function _G.equal(a, b, level)
	level = level or 1

	if a ~= b then
		if type(a) == "string" then a = string.format("%q", a) end

		if type(b) == "string" then b = string.format("%q", b) end

		diff(a, b)
		error(tostring(a) .. " ~= " .. tostring(b), level + 1)
	end
end

function _G.diff(input, expect)
	local a = os.tmpname()
	local b = os.tmpname()

	do
		local f = io.open(a, "w")
		f:write(input)
		f:close()
	end

	do
		local f = io.open(b, "w")
		f:write(expect)
		f:close()
	end

	os.execute("meld " .. a .. " " .. b)
end

local path = ...
local is_coverage = path == "coverage"
if is_coverage then
	path = nil
end

if path == "remove_coverage" then
	local util = require("examples.util")
	local paths = util.GetFilesRecursively("./", "lua.coverage")
	for _, path in ipairs(paths) do
		os.remove(path)
	end
	return
end

local covered = {}

if is_coverage then
	preprocess.Init()

	function preprocess.Preprocess(code, name, path, from)
		if from == "package" then
			if path and path:find("^nattlua/") and not path:find("^nattlua/other") then 
				covered[name] = path
				return coverage.Preprocess(code, name) 
			end
		end
		return code
	end
end

if path and path:sub(-4) == ".lua" then
	assert(loadfile(path))()
else
	local what = path
	local path = "test/" .. ((what and what .. "/") or "nattlua/")

	for path in io.popen("find " .. path):lines() do
		if not path:find("/file_importing/", nil, true) then
			if path:sub(-4) == ".lua" then assert(loadfile(path))() end
		end
	end

	for path in io.popen("find " .. path):lines() do
		if not path:find("/file_importing/", nil, true) then
			if path:sub(-5) == ".nlua" then
				require("test.helpers").RunCode(io.open(path, "r"):read("*all"))
			end
		end
	end
end

if is_coverage then
	for name, path in pairs(covered) do
		local coverage = coverage.Collect(name)
		if coverage then
			local f = io.open(path .. ".coverage", "w")
			f:write(coverage)
			f:close()
		else
			print("unable to find coverage information for " .. name)
		end
	end
end