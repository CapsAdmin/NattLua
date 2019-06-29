local syntax = {}

syntax.SymbolCharacters = {
    ",", ";",
    "(", ")", "{", "}", "[", "]",
    "=", "::", "\"", "'",
}

syntax.NumberAnnotations = {
    "ull", "ll", "ul", "i",
}

syntax.Keywords = {
    "and", "break", "do", "else", "elseif", "end",
    "false", "for", "function", "if", "in", "of", "local",
    "nil", "not", "or", "repeat", "until", "return", "then",
    "...",

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
    "-", "#", "not", "~",
}

syntax.PostfixOperators = {
    -- these are just to make sure all code is covered by tests
    "++", "ÆØÅ", "ÆØÅÆ",
}

syntax.BinaryOperators = {
    {"or"},
    {"and"},
    {"<", ">", "<=", ">=", "~=", "=="},
    {"|"},
    {"~"},
    {"&"},
    {"<<", ">>"},
    {"R.."}, -- right associative
    {"+", "-"},
    {"*", "/", "//", "%"},
    {"R^"}, -- right associative
    {".", ":"},
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
}

do
    local B = string.byte

    function syntax.IsLetter(c)
        return
            (c >= B'a' and c <= B'z') or
            (c >= B'A' and c <= B'Z') or
            (c == B'_' or c >= 128)
    end

    function syntax.IsDuringLetter(c)
        return
            (c >= B'a' and c <= B'z') or
            (c >= B'0' and c <= B'9') or
            (c >= B'A' and c <= B'Z') or
            (c == B'_' or c >= 128)
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

do -- extend the symbol characters from grammar rules
    for _, symbol in pairs(syntax.PrefixOperators) do
        if symbol:find("%p") then
            table.insert(syntax.SymbolCharacters, symbol)
        end
    end

    for _, symbol in pairs(syntax.PostfixOperators) do
        if symbol:find("%p") then
            table.insert(syntax.SymbolCharacters, symbol)
        end
    end

    for _, group in ipairs(syntax.BinaryOperators) do
        for _, token in ipairs(group) do
            if token:find("%p") then
                if token:sub(1, 1) == "R" then
                    token = token:sub(2)
                end

                table.insert(syntax.SymbolCharacters, token)
            end
        end
    end

    for _, symbol in ipairs(syntax.Keywords) do
        if symbol:find("%p") then
            table.insert(syntax.SymbolCharacters, symbol)
        end
    end
end

do
    for k, v in pairs(syntax.BinaryOperatorFunctionTranslate) do
        local a,b,c = v:match("(.-)A(.-)B(.*)")
        syntax.BinaryOperatorFunctionTranslate[k] = {" " .. a, b, c .. " "}
    end

    for k, v in pairs(syntax.PrefixOperatorFunctionTranslate) do
        local a, b = v:match("^(.-)A(.-)$")
        syntax.PrefixOperatorFunctionTranslate[k] = {" " .. a, b .. " "}
    end

    for k, v in pairs(syntax.PostfixOperatorFunctionTranslate) do
        local a, b = v:match("^(.-)A(.-)$")
        syntax.PostfixOperatorFunctionTranslate[k] = {" " .. a, b .. " "}
    end
end

do -- grammar rules
    function syntax.IsValue(token)
        return token.type == "number" or token.type == "string" or syntax.KeywordValues[token.value]
    end

    function syntax.IsDefinetlyNotStartOfExpression(token)
        return
        not token or token.type == "end_of_file" or
        token.value == "}" or token.value == "," or
        token.value == "[" or token.value == "]" or
        (
            syntax.IsKeyword(token) and
            not syntax.IsPrefixOperator(token) and
            not syntax.IsValue(token) and
            token.value ~= "function"
        )
    end

    function syntax.IsOperator(token)
        return syntax.BinaryOperators[token.value] ~= nil
    end

    function syntax.GetLeftOperatorPriority(token)
        return syntax.BinaryOperators[token.value] and syntax.BinaryOperators[token.value][1]
    end

    function syntax.GetRightOperatorPriority(token)
        return syntax.BinaryOperators[token.value] and syntax.BinaryOperators[token.value][2]
    end

    function syntax.GetFunctionForBinaryOperator(token)
        return syntax.BinaryOperatorFunctionTranslate[token.value]
    end

    function syntax.GetFunctionForPrefixOperator(token)
        return syntax.PrefixOperatorFunctionTranslate[token.value]
    end

    function syntax.GetFunctionForPostfixOperator(token)
        return syntax.PostfixOperatorFunctionTranslate[token.value]
    end

    function syntax.IsPrefixOperator(token)
        return syntax.PrefixOperators[token.value]
    end

    function syntax.IsPostfixOperator(token)
        return syntax.PostfixOperators[token.value]
    end

    function syntax.IsKeyword(token)
        return syntax.Keywords[token.value]
    end

    local temp = {}
    for priority, group in ipairs(syntax.BinaryOperators) do
        for _, token in ipairs(group) do
            if token:sub(1, 1) == "R" then
                temp[token:sub(2)] = {priority + 1, priority}
            else
                temp[token] = {priority, priority}
            end
        end
    end
    syntax.BinaryOperators = temp

    local function to_lookup(tbl)
        local out = {}
        for _, v in pairs(tbl) do
            out[v] = v
        end
        return out
    end

    syntax.PrefixOperators = to_lookup(syntax.PrefixOperators)
    syntax.PostfixOperators = to_lookup(syntax.PostfixOperators)
    syntax.Keywords = to_lookup(syntax.Keywords)
    syntax.KeywordValues = to_lookup(syntax.KeywordValues)
end

return syntax