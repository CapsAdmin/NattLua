local cli = require("nattlua.cli.init")
local fs = require("nattlua.other.fs")
local DIR = "./test/tests/cli_ignore_temp"

local function has(list, needle)
	for _, p in ipairs(list) do
		if p:find(needle, nil, true) then return true end
	end

	return false
end

local function get(ignorefiles)
	return cli.get_files{path = DIR .. "/*", ignorefiles = ignorefiles, ext = {".lua"}}
end

os.execute("rm -rf " .. DIR)
fs.create_directory(DIR)
fs.create_directory(DIR .. "/tmp")
fs.create_directory(DIR .. "/tmp/deep")
fs.create_directory(DIR .. "/src")
fs.write(DIR .. "/keep.lua", "return 1")
fs.write(DIR .. "/src/keep.lua", "return 1")
fs.write(DIR .. "/tmp/ignored.lua", "return 1")
fs.write(DIR .. "/tmp/deep/ignored.lua", "return 1")
local ok, err = pcall(function()
	-- nothing ignored
	local all = get(nil)
	assert(#all == 4)
	assert(has(all, "/tmp/ignored.lua"))
	assert(has(all, "/tmp/deep/ignored.lua"))

	-- paths are prefixed with the given path, so a bare directory pattern must not be anchored to "./"
	for _, pattern in ipairs({"/tmp/", "tmp/*", "^%./test/tests/cli_ignore_temp/tmp/"}) do
		local res = get({pattern})
		assert(#res == 2, pattern)
		assert(not has(res, "/tmp/"), pattern)
		assert(has(res, "/keep.lua"), pattern)
		assert(has(res, "/src/keep.lua"), pattern)
	end

	-- "^%./tmp/" only matches when walking "./*" from the project root, not a subdirectory
	assert(#get({"^%./tmp/"}) == 4)
end)
os.execute("rm -rf " .. DIR)
assert(ok, err)
