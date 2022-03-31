--require("nattlua.other.helpers").GlobalLookup()
local io = require("io")
package.path = package.path .. ";nattlua/other/?.lua"

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

local test_path = ...
local coverage_path = test_path

if test_path == "nattlua/analyzer/statements/assignment.lua" then
    test_path = "test/nattlua/analyzer/assignment.lua"
end

if test_path then
    local luacov = require("nattlua.other.luacov")
    luacov.init({
        include = {
            coverage_path,
        }
    })
end

print("running " .. (test_path or "all tests"))

if test_path and test_path:sub(-4) == ".lua" then
	assert(loadfile(test_path))()
else
	local what = test_path
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