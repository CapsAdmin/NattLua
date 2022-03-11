local nl = require("nattlua")
local entry = "./nattlua.lua"
io.write("parsing " .. entry)
local c = assert(nl.File(entry, {
	annotate = true,
	inline_require = true,
}))
local lua_code = c:Emit(
	{
		preserve_whitespace = false,
		string_quote = "\"",
		no_semicolon = true,
		use_comment_types = true,
		annotate = true,
		force_parenthesis = true,
		extra_indent = {
			Start = {to = "Stop"},
			Toggle = "toggle",
		},
	}
)
io.write(" - OK\n")
io.write("output is " .. #lua_code .. " bytes\n")
-- double check that the lua_code is valid
io.write("checking if lua_code is loadable")
local func, err = loadstring(lua_code)

if not func then
	io.write(" - FAILED\n")
	io.write(err .. "\n")
	local f = io.open("error_build_output.lua", "w")
	f:write(lua_code)
	f:close()
	return
end

io.write(" - OK\n")
-- run tests before we write the file
local f = io.open("temp_build_output.lua", "w")
f:write(lua_code)
f:close()
io.write("running tests with temp_build_output.lua")
io.flush()
local exit_code = os.execute("luajit -e 'require(\"temp_build_output\") require(\"test\")'")

if exit_code == 0 then
	io.write(" - OK\n")
	io.write("writing build_output.lua")
	local f = io.open("build_output.lua", "w")
	f:write(lua_code)
	f:close()
	io.write(" - OK\n")
else
	io.write(" - FAIL\n")
end

os.remove("temp_build_output.lua")
