local syntax = {}

syntax.SymbolCharacters = {
    ",", ";",
    "(", ")", "{", "}", "[", "]",
    "=", "::", "\"", "'",

    "<|", "|>",
}

syntax.NumberAnnotations = {
    "ull", "ll", "ul", "i",
}

syntax.Keywords = {
    "do", "end",
    "if", "then", "else", "elseif",
    "for", "in",
    "while", "repeat", "until",
    "break", "return",
    "local", "function",
    "and", "not", "or",

    --"import",

    -- these are just to make sure all code is covered by tests
    "ÆØÅ", "ÆØÅÆ",
}

syntax.KeywordValues = {
    "...",
    "nil",
    "true",
    "false",
}

syntax.PrefixOperators = {
    "-", "#", "not", "!", "~",
}

syntax.PostfixOperators = {
    -- these are just to make sure all code is covered by tests
    "++", "ÆØÅ", "ÆØÅÆ",
}

syntax.BinaryOperators = {
    {"or", "||"},
    {"and", "&&"},
    {"<", ">", "<=", ">=", "~=", "==", "!="},
    {"|"},
    {"~"},
    {"&"},
    {"<<", ">>"},
    {"R.."}, -- right associative
    {"+", "-"},
    {"*", "/", "/idiv/", "%"},
    {"R^"}, -- right associative
}

syntax.PrimaryBinaryOperators = {
    ".", ":",
}

syntax.BinaryOperatorFunctionTranslate = {
    [">>"] = "bit.rshift(A, B)",
    ["<<"] = "bit.lshift(A, B)",
    ["|"] = "bit.bor(A, B)",
    ["&"] = "bit.band(A, B)",
    ["//"] = "math.floor(A / B)",
    ["~"] = "bit.bxor(A, B)",
}

syntax.PrefixOperatorFunctionTranslate = {
    ["~"] = "bit.bnot(A)",
}

syntax.PostfixOperatorFunctionTranslate = {
    ["++"] = "(A+1)",
    ["ÆØÅ"] = "(A)",
    ["ÆØÅÆ"] = "(A)",
}

do 
    syntax.typesystem = {}

    for k,v in pairs(syntax) do
        syntax.typesystem[k] = v
    end

    syntax.typesystem.PrefixOperators = {
        "-", "#", "not", "~", "typeof", "$", "unique",
    }

    syntax.typesystem.PrimaryBinaryOperators = {
        ".",
    }

    syntax.typesystem.BinaryOperators = {
        {"or"},
        {"and"},
        {"extends"},
        {"<", ">", "<=", ">=", "~=", "=="},
        {"|"},
        {"~"},
        {"&"},
        {"<<", ">>"},
        {"R.."}, -- right associative
        {"+", "-"},
        {"*", "/", "/idiv/", "%"},
        {"R^"}, -- right associative
    }

    require("oh.base_syntax")(syntax.typesystem)
end

require("oh.base_syntax")(syntax)

return syntax