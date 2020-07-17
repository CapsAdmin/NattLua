local oh = require("oh")

local function check(code)
    local o = oh.Code(code)
    o.Lexer = require("oh.c.lexer")
    o.Parser = require("oh.c.parser")
    o.Emitter = require("oh.c.emitter")
    assert(o:Parse()):Emit()
    for i,v in ipairs(o.Tokens) do

    end
end


it("macro newline escape", function()
    check("#define\n\\ FOO \n\\ 1\n\\ 2 foo 3\n\\ 4 \n\\5")
end)

it("define identifier token-string", function()
    check("#define FOO 1 2 foo 3 4 5")
end)

it("define identifier args", function()
    check("#define FOO(foo, bar, faz) 1 2 foo 3 4 5")
end)

it("include", function()
    check("#include \"foo/bar/faz.c\"")
    check("#include <foo/bar/faz.c>")
end)

it("line", function()
    check("#line 123 \"aaaa.lua\"")
end)

it("undef", function()
    check("#undef")
end)