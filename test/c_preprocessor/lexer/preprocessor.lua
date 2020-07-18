local oh = require("oh")


local f = io.open("./temp.c", "w")
f:write([[


    #define MIN(a,b) ((a)<(b)?(a):(b))

#define l2ol <stdio.h>

#define lol(a) int main()      a

lol({
    printf(l2ol

    "Hello World");

    MIN(5,2)

    return 0;
})

]])
f:close()
print(io.popen("gcc -E ./temp.c", "r"):read("*all"))
os.remove("./temp.c")

local tprint = require("libraries.tprint")

local function tokenize(code)
    local o = oh.Code(code)
    o.Lexer = require("oh.c_preprocessor.lexer")
    o.Parser = require("oh.c_preprocessor.parser")
    o.Emitter = require("oh.c_preprocessor.emitter")
    assert(o:Lex())
    return o.Tokens
end

local function parse(code)
    local o = oh.Code(code)
    o.Lexer = require("oh.c_preprocessor.lexer")
    o.Parser = require("oh.c_preprocessor.parser")
    o.Emitter = require("oh.c_preprocessor.emitter")
    assert(o:Parse())
    return o.SyntaxTree
end

test("macro newline escape", function()
    local tokens = tokenize("define\\\n FOO \\\n 1\\\n 2 foo 3\\\n 4 \\\n5")
    equal(tokens[1].type, "keyword")
    equal(#tokens, 9)
end)

test("define identifier token-string", function()
    local syntax_tree = parse("define FOO 1 2 3")
    equal(syntax_tree.statements[1].kind, "define")
end)

test("define identifier args", function()
    local syntax_tree = parse("define FOO(foo, bar, faz) 1 2 foo 3 4 5")
    equal(syntax_tree.statements[1].kind, "define")
end)

test("include double quote", function()
    local syntax_tree = parse("include \"foo/bar/faz.c\"")
    equal(syntax_tree.statements[1].path.value, "\"foo/bar/faz.c\"")
end)

test("include angle bracket", function()
    local syntax_tree = parse("include <foo/bar/faz.c>")

    local path = ""
    for _, token in ipairs(syntax_tree.statements[1].path) do
        path = path .. token.value
    end
    equal(path, "foo/bar/faz.c")
end)

test("define", function()
    local syntax_tree = parse("define foo")
end)
do return end


test("line", function()
    check("line 123 \"aaaa.lua\"")
end)
test("macro expansion", function()
    check[[
        #define HE HI
		#define LLO _THERE
		#define HELLO "HI THERE"
		#define CAT(a,b) a##b
		#define XCAT(a,b) CAT(a,b)
		#define CALL(fn) fn(HE,LLO)

		CAT(HE,LLO) // "HI THERE", because concatenation occurs before normal expansion
		XCAT(HE,LLO) // HI_THERE, because the tokens originating from parameters ("HE" and "LLO") are expanded first
		CALL(CAT) // "HI THERE", because parameters are expanded first
    ]]
end)