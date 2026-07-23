local Syntax = require("nattlua.syntax.syntax").New
local runtime = Syntax()
runtime:AddSymbolCharacters{
	",",
	";",
	"=",
	"::",
	{"(", ")"},
	{"{", "}"},
	{"[", "]"},
	{"\"", "\""},
	{"'", "'"},
	{"<|", "|>"},
}
runtime:AddNumberAnnotations{
	"ull",
	"ll",
	"ul",
	"i",
}
runtime:AddKeywords{
	"do",
	"end",
	"if",
	"then",
	"else",
	"elseif",
	"for",
	"in",
	"while",
	"repeat",
	"until",
	"break",
	"return",
	"local",
	"function",
	"and",
	"not",
	"or",
	-- these are just to make sure all code is covered by tests
	"ÆØÅ",
	"ÆØÅÆ",
}
-- these are keywords, but can be used as names
runtime:AddNonStandardKeywords{
	"continue",
	"import",
	"literal",
	"ref",
	"goto",
	"const",
}
runtime:AddKeywordValues{
	"...",
	"nil",
	"true",
	"false",
}
runtime:AddPrefixOperators{"+", "-", "#", "not", "!", "~"}
runtime:AddPostfixOperators{
	-- these are just to make sure all code is covered by tests
	"++",
	"ÆØÅ",
	"ÆØÅÆ",
}
-- short function expression syntax
runtime:AddSymbols({"->", "|"})
runtime:AddBinaryOperators{
	{"or", "||", "??"},
	{"and", "&&"},
	{"<", ">", "<=", ">=", "~=", "==", "!="},
	{"|"},
	{"~"},
	{"&"},
	{"<<", ">>", "~>>"},
	{"R.."}, -- right associative
	{"+", "-"},
	{"*", "/", "%", "//"},
	{"R^"}, -- right associative
	{"R?"}, -- ternary ? (lowest precedence, right-assoc)
}
runtime:AddPrimaryBinaryOperators{
	".",
	":",
}
-- these are really here just for coverage
runtime:AddBinaryOperatorFunctionTranslate{
	["ÆØÅØÆ"] = "(A, B)",
}
runtime:AddPrefixOperatorFunctionTranslate{
	["ÆÆÆ"] = "(A)",
}
runtime:AddPostfixOperatorFunctionTranslate{
	["++"] = "(A+1)",
	["ÆØÅ"] = "(A)",
	["ÆØÅÆ"] = "(A)",
}
-- compound assignment operators (added as symbols for lexer recognition)
runtime:AddSymbols{
	"+=",
	"-=",
	"*=",
	"/=",
	"//=",
	"%=",
	"&=",
	"|=",
	"<<=",
	">>=",
	"..=",
}
-- these speed up the lexer a little bit
-- if these are removed, we cannot do token.sub_type == "import" checks
-- and have to do token:ValueEquals("import") instead
-- ValueEquals will scan the code of the token every time it is called
runtime:AddReadSymbols{
	"import",
	"require",
	"dofile",
	"loadfile",
	"loadstring",
	"import_data",
	"expand",
	"sizeof",
	"cdef",
	"const",
}
return runtime
