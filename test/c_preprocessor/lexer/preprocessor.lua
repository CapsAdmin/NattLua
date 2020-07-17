local oh = require("oh")

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

it("macro newline escape", function()
    local tokens = tokenize("define\\\n FOO \\\n 1\\\n 2 foo 3\\\n 4 \\\n5")
    equal(tokens[1].type, "macro")
    equal(#tokens, 2)
end)

it("define identifier token-string", function()
    local syntax_tree = parse("define FOO 1 2 foo 3 4 5")
    tprint(syntax_tree)
end)
do return end
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

it("macro expansion", function()
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