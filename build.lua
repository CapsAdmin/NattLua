local nl = require("nattlua")

local entry = "./nattlua.lua"
io.write("parsing "..entry)
local c = assert(nl.File(entry, {
    annotate = true,
    inline_require = true,
}))

local code = c:Emit({
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
})
io.write(" - OK\n")

io.write("output is "..#code.." bytes\n")

-- double check that the code is valid
io.write("checking if code is loadable")
assert(loadstring(code))()
io.write(" - OK\n")

-- run tests before we write the file
local f = io.open("temp_build_output.lua", "w")
f:write(code)
f:close()

io.write("running tests with temp_build_output.lua")
io.flush()
local code = os.execute("luajit -e 'require(\"temp_build_output\") require(\"test\")'")

if code == 0 then 
    io.write(" - OK\n")

    io.write("writing build_output.lua")
    local f = io.open("build_output.lua", "w")
    f:write(code)
    f:close()
    io.write(" - OK\n")
else
    io.write(" - FAIL\n")
end

os.remove("temp_build_output.lua")