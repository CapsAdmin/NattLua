local nl = require("nattlua")

local builder = assert(nl.File("example_projects/luajit/src/main.nlua"))

function builder:OnResolvePath(path)
    return "example_projects/luajit/src/" .. path
end

assert(builder:Lex())
assert(builder:Parse())

assert(builder:Analyze())

local code, err = builder:Emit({
    preserve_whitespace = true, 
    string_quote = "\"",
    no_semicolon = true,
    use_comment_types = true,
    annotate = true,
    force_parenthesis = true,
    extra_indent = {
        Start = {to = "Stop"},
        Toggle = "toggle",
    }
})

-- todo
code = io.open("nattlua/runtime/base_runtime.lua"):read("*all") .. "\n" .. code

local file = io.open("example_projects/luajit/out.lua", "w")
file:write(code)
file:close()
print("===RUNNING CODE===")
require("example_projects.luajit.out")