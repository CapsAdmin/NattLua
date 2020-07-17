local syntax = {}

syntax.SymbolCharacters = {
    ",", "(", ")",
}

syntax.NumberAnnotations = {
    "ull", "ll", "ul", "i",
}

syntax.Keywords = {
    "define",
    "undef",
    "ifdef",
    "else",
    "endif",
    "if",
}

syntax.KeywordValues = {
    "...",
    "nil",
    "true",
    "false",
}

syntax.PrefixOperators = {
    "#", "#@"
}

syntax.PostfixOperators = {
    "++", "--",
}


syntax.BinaryOperators = {
    {"##"},
    {"||"},
    {"&&"},
    {"<", ">", "<=", ">=", "!=", "=="},
    {"|"},
    {"~"},
    {"&"},
    {"<<", ">>"},
    {"+", "-"},
    {"*", "/", "%"},
}

syntax.PrimaryBinaryOperators = {
    ".",
}

do
    local B = string.byte

    function syntax.IsLetter(c)
        return
            (c >= B'a' and c <= B'z') or
            (c >= B'A' and c <= B'Z') or
            (c == B'_' or c >= 127)
    end

    function syntax.IsDuringLetter(c)
        return
            (c >= B'a' and c <= B'z') or
            (c >= B'0' and c <= B'9') or
            (c >= B'A' and c <= B'Z') or
            (c == B'_' or c >= 127)
    end

    function syntax.IsNumber(c)
        return (c >= B'0' and c <= B'9')
    end

    function syntax.IsSpace(c)
        return c > 0 and c <= 32
    end

    function syntax.IsSymbol(c)
        return c ~= B'_' and (
            (c >= B'!' and c <= B'/') or
            (c >= B':' and c <= B'@') or
            (c >= B'[' and c <= B'`') or
            (c >= B'{' and c <= B'~')
        )
    end
end

return require("oh.syntax")(syntax)