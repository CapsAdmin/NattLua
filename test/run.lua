local io = require("io")
local pcall = _G.pcall
--require("nattlua.other.helpers").GlobalLookup()
local map -- = {}
if map then
	debug.sethook(
		function(evt)
			if evt ~= "line" then return end

			local info = debug.getinfo(2, "Sl")

			if info.source:sub(1, 10) == "@./nattlua" then
				local src = info.source:sub(2)
				map[src] = map[src] or {}
				map[src][info.currentline] = (map[src][info.currentline] or 0) + 1
			end
		end,
		"l"
	)
end

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

if path and path:sub(-4) == ".lua" then
	assert(loadfile(path))()
else
	local what = path
	local path = "test/" .. ((what and what .. "/") or "nattlua/")

	for path in io.popen("find " .. path):lines() do
		if not path:find("/file_importing/", nil, true) then
			if path:sub(-4) == ".lua" then
				assert(loadfile(path))()
			end
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

if map then
	for k, v in pairs(map) do
		if k:find("nattlua/", 1, true) then
			local f = io.open(k .. ".coverage", "w")
			local i = 1

			for line in io.open(k):lines() do
				if map[k][i] then f:write("\n") else f:write(line, "\n") end

				i = i + 1
			end

			f:close()
		end
	end
end
