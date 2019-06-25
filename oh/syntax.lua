local util = require("oh.util")

local syntax = {}

syntax.UTF8 = true

syntax.SymbolCharacters = {
    ".", ",", ":", ";",
    "(", ")", "{", "}", "[", "]",
    "=", "::", "\"", "'", "`",
}

syntax.Keywords = {
    "and", "break", "do", "else", "elseif", "end",
    "false", "for", "function", "if", "in", "of", "local",
    "nil", "not", "or", "repeat", "until", "return", "then",

    "...",

    --"async", "interface", "struct", "as", "@",
}

syntax.KeywordValues = {
    "...",
    "nil",
    "true",
    "false",
}

syntax.UnaryOperators = {
    "-", "#", "not", "~",

    -- glua
   -- "!",
}

syntax.BinaryOperators = {
    {"or", "||"},
    {"and", "&&"},
    {"<", ">", "<=", ">=", "~=", "!=", "=="},
    {"|"},
    {"~"},
    {"&"},
    {"<<", ">>"},
    {"R.."}, -- right associative
    {"+", "-"},
    {"*", "/", "//", "%"},
    {"R^"}, -- right associative
}

syntax.BinaryOperatorFunctionTranslate = {
    [">>"] = "bit.rshift(A, B)",
    ["<<"] = "bit.lshift(A, B)",
    ["|"] = "bit.bor(A, B)",
    ["&"] = "bit.band(A, B)",
    ["//"] = "math.floor(A / B)",
    ["~"] = "bit.bxor(A, B)",
}

syntax.UnaryOperatorFunctionTranslate = {
    ["~"] = "bit.bnot(A)",
}

-- temp
function math.floordiv(a, b)
    return math.floor(a / b)
end

do
    local map = {}

    map.space = syntax.SpaceCharacters or {" ", "\n", "\r", "\t"}

    if syntax.NumberCharacters then
        map.number = syntax.NumberCharacters
    else
        map.number = {}
        for i = 0, 9 do
            map.number[i+1] = tostring(i)
        end
    end

    if syntax.LetterCharacters then
        map.letter = syntax.LetterCharacters
    else
        map.letter = {"_"}

        for i = string.byte("A"), string.byte("Z") do
            table.insert(map.letter, string.char(i))
        end

        for i = string.byte("a"), string.byte("z") do
            table.insert(map.letter, string.char(i))
        end
    end

    if syntax.SymbolCharacters then
        map.symbol = syntax.SymbolCharacters
    else
        error("syntax.SymbolCharacters not defined", 2)
    end

    map.end_of_file = {syntax.EndOfFileCharacter or ""}

    syntax.CharacterMap = map
end

do -- extend the symbol map from grammar rules
    for _, symbol in pairs(syntax.UnaryOperators) do
        if symbol:find("%p") then
            table.insert(syntax.CharacterMap.symbol, symbol)
        end
    end

    for _, group in ipairs(syntax.BinaryOperators) do
        for _, token in ipairs(group) do
            if token:find("%p") then
                if token:sub(1, 1) == "R" then
                    token = token:sub(2)
                end

                table.insert(syntax.CharacterMap.symbol, token)
            end
        end
    end

    for _, symbol in ipairs(syntax.Keywords) do
        if symbol:find("%p") then
            table.insert(syntax.CharacterMap.symbol, symbol)
        end
    end
end

do
    local temp = {}
    for type, chars in pairs(syntax.CharacterMap) do
        for _, char in ipairs(chars) do
            temp[char] = type
        end
    end
    syntax.CharacterMap = temp

    syntax.LongestSymbolLength = 0
    syntax.SymbolLookup = {}

    for str, type in pairs(syntax.CharacterMap) do
        if type == "symbol" then
            local chars = util.UTF8ToTable(str)

            local node = syntax.SymbolLookup
            for i, char in ipairs(chars) do
                node[char] = node[char] or {}
                node = node[char]
            end
            node.DONE = {str = str, length = #chars}

            syntax.LongestSymbolLength = math.max(syntax.LongestSymbolLength, #chars)
        end
    end
end

do
    for k, v in pairs(syntax.BinaryOperatorFunctionTranslate) do
        local a,b,c = v:match("(.-)A(.-)B(.*)")
        syntax.BinaryOperatorFunctionTranslate[k] = {" " .. a, b, c .. " "}
    end

    for k, v in pairs(syntax.UnaryOperatorFunctionTranslate) do
        local a, b = v:match("^(.-)A(.-)$")
        syntax.UnaryOperatorFunctionTranslate[k] = {" " .. a, b .. " "}
    end
end

do -- grammar rules
    function syntax.GetCharacterType(char)
        return syntax.CharacterMap[char]
    end

    function syntax.IsValue(token)
        return token.type == "number" or token.type == "string" or syntax.KeywordValues[token.value]
    end

    function syntax.IsDefinetlyNotStartOfExpression(token)
        return
        token.value == "}" or token.value == "," or
        token.value == "[" or token.value == "]" or
        (
            syntax.IsKeyword(token) and
            not syntax.IsUnaryOperator(token) and
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

    function syntax.GetFunctionForOperator(token)
        return syntax.BinaryOperatorFunctionTranslate[token.value]
    end

    function syntax.GetFunctionForUnaryOperator(token)
        return syntax.UnaryOperatorFunctionTranslate[token.value]
    end

    function syntax.IsUnaryOperator(token)
        return syntax.UnaryOperators[token.value]
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

    do
      local temp = {}
      for _, val in pairs(syntax.UnaryOperators) do
          temp[val] = true
      end
      syntax.UnaryOperators = temp
    end

    do
      local temp = {}
      for _, v in pairs(syntax.Keywords) do
          temp[v] = v
      end
      syntax.Keywords = temp
    end

    do
      local temp = {}
      for _, v in pairs(syntax.KeywordValues) do
          temp[v] = v
      end
      syntax.KeywordValues = temp
    end
end

return syntax