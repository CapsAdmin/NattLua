local syntax = {}

--[[# type syntax.@Name = "Syntax" ]]

syntax.SymbolCharacters --[[#: {[number] = string} ]] = {
    ",", ";",
    "(", ")", "{", "}", "[", "]",
    "=", "::", "\"", "'",
    "<|", "|>",
}

syntax.NumberAnnotations --[[#: {[number] = string} ]]  = {
    "ull", "ll", "ul", "i",
}

syntax.Keywords --[[#: {[number] = string} ]]  = {
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

syntax.KeywordValues --[[#: {[number] = string} ]]  = {
    "...",
    "nil",
    "true",
    "false",
}

syntax.PrefixOperators --[[#: {[number] = string} ]]  = {
    "-", "#", "not", "!", "~",
}

syntax.PostfixOperators --[[#: {[number] = string} ]]  = {
    -- these are just to make sure all code is covered by tests
    "++", "ÆØÅ", "ÆØÅÆ",
}

syntax.BinaryOperators --[[#: {[number] = {[number] = string}} ]]  = {
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

syntax.PrimaryBinaryOperators --[[#: {[number] = string} ]]  = {
    ".", ":",
}

syntax.BinaryOperatorFunctionTranslate --[[#: {[string] = string} ]]  = {
    [">>"] = "bit.rshift(A, B)",
    ["<<"] = "bit.lshift(A, B)",
    ["|"] = "bit.bor(A, B)",
    ["&"] = "bit.band(A, B)",
    ["//"] = "math.floor(A / B)",
    ["~"] = "bit.bxor(A, B)",
}

syntax.PrefixOperatorFunctionTranslate --[[#: {[string] = string} ]]  = {
    ["~"] = "bit.bnot(A)",
}

syntax.PostfixOperatorFunctionTranslate --[[#: {[string] = string} ]]  = {
    ["++"] = "(A+1)",
    ["ÆØÅ"] = "(A)",
    ["ÆØÅÆ"] = "(A)",
}

do 
    syntax.typesystem = {}

    for k,v in pairs(syntax) do
        syntax.typesystem[k] = v
    end

    --[[# type syntax.typesystem.@Name = "SyntaxTypesystem" ]]


    syntax.typesystem.PrefixOperators --[[#: {[number] = string} ]]  = {
        "-", "#", "not", "~", "typeof", "$", "unique", "out", "literal", "supertype"
    }

    syntax.typesystem.PrimaryBinaryOperators --[[#: {[number] = string} ]]  = {
        ".",
    }

    syntax.typesystem.BinaryOperators --[[#: {[number] = {[number] = string}} ]]  = {
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

    require("nattlua.syntax.base_syntax")(syntax.typesystem)
end

require("nattlua.syntax.base_syntax")(syntax)

return syntax