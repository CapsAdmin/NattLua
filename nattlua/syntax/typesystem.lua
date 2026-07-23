local Syntax = require("nattlua.syntax.syntax").New
local typesystem = Syntax()
typesystem:AddSymbolCharacters{
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
typesystem:AddNumberAnnotations{"ull", "ll", "ul", "i"}
typesystem:AddKeywords{
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
	"as",
	-- these are just to make sure all code is covered by tests
	"ÆØÅ",
	"ÆØÅÆ",
}
-- these are keywords, but can be used as names
typesystem:AddNonStandardKeywords{
	"continue",
	"import",
	"literal",
	"ref",
	"analyzer",
	"type",
}
typesystem:AddKeywordValues{
	"...",
	"nil",
	"true",
	"false",
}
typesystem:AddPostfixOperators{ -- these are just to make sure all code is covered by tests
	"++",
	"ÆØÅ",
	"ÆØÅÆ",
}
typesystem:AddPrimaryBinaryOperators{
	".",
	"?.",
	":",
}
-- these are really here just for coverage
typesystem:AddBinaryOperatorFunctionTranslate{
	["ÆØÅØÆ"] = "(A, B)",
}
typesystem:AddPrefixOperatorFunctionTranslate{
	["ÆÆÆ"] = "(A)",
}
typesystem:AddPostfixOperatorFunctionTranslate{
	["++"] = "(A+1)",
	["ÆØÅ"] = "(A)",
	["ÆØÅÆ"] = "(A)",
}
typesystem:AddPostfixOperatorFunctionTranslate{
	["++"] = "(A+1)",
	["ÆØÅ"] = "(A)",
	["ÆØÅÆ"] = "(A)",
}
typesystem:AddPrefixOperators{
	"-",
	"#",
	"not",
	"!",
	"~",
	"typeof",
	"$",
	"unique",
	"ref",
	"literal",
	"supertype",
	"expand",
}
typesystem:AddBinaryOperators{
	{"or"},
	{"and"},
	{"extends"},
	{"subsetof"},
	{"supersetof"},
	{"<", ">", "<=", ">=", "~=", "=="},
	{"|"},
	{"~"},
	{"&"},
	{"<<", ">>", "~>>"},
	{"R.."}, -- right associative
	{"+", "-"},
	{"*", "/", "%", "//"},
	{"R^"}, -- right associative
}
return typesystem
