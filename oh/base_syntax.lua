local syntax = ...

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

do -- extend the symbol characters from grammar rules
    local function add_symbols(tbl)
        if not tbl then return end

        for _, symbol in pairs(tbl) do
            if symbol:find("%p") then
                table.insert(syntax.SymbolCharacters, symbol)
            end
        end
    end

    local function add_binary_symbols(tbl)
        if not tbl then return end

        for _, group in ipairs(tbl) do
            for _, token in ipairs(group) do
                if token:find("%p") then
                    if token:sub(1, 1) == "R" then
                        token = token:sub(2)
                    end

                    table.insert(syntax.SymbolCharacters, token)
                end
            end
        end
    end

    add_binary_symbols(syntax.BinaryOperators)
    add_binary_symbols(syntax.BinaryTypeOperators)

    add_symbols(syntax.PrefixOperators)
    add_symbols(syntax.PostfixOperators)
    add_symbols(syntax.PrimaryBinaryOperators)

    add_symbols(syntax.PrefixTypeOperators)
    add_symbols(syntax.PostfixTypeOperators)
    add_symbols(syntax.PrimaryBinaryTypeOperators)

    for _, str in ipairs(syntax.KeywordValues) do
        table.insert(syntax.Keywords, str)
    end

    for _, symbol in ipairs(syntax.Keywords) do
        if symbol:find("%p") then
            table.insert(syntax.SymbolCharacters, symbol)
        end
    end
end

do
    syntax.BinaryOperatorFunctionTranslate = syntax.BinaryOperatorFunctionTranslate or {}
    for k, v in pairs(syntax.BinaryOperatorFunctionTranslate) do
        local a,b,c = v:match("(.-)A(.-)B(.*)")
        syntax.BinaryOperatorFunctionTranslate[k] = {" " .. a, b, c .. " "}
    end

    function syntax.GetFunctionForBinaryOperator(token)
        return syntax.BinaryOperatorFunctionTranslate[token.value]
    end
end

do
    syntax.PrefixOperatorFunctionTranslate = syntax.PrefixOperatorFunctionTranslate or {}
    for k, v in pairs(syntax.PrefixOperatorFunctionTranslate or {}) do
        local a, b = v:match("^(.-)A(.-)$")
        syntax.PrefixOperatorFunctionTranslate[k] = {" " .. a, b .. " "}
    end

    function syntax.GetFunctionForPrefixOperator(token)
        return syntax.PrefixOperatorFunctionTranslate[token.value]
    end
end


do
    syntax.PostfixOperatorFunctionTranslate = syntax.PostfixOperatorFunctionTranslate or {}
    for k, v in pairs(syntax.PostfixOperatorFunctionTranslate) do
        local a, b = v:match("^(.-)A(.-)$")
        syntax.PostfixOperatorFunctionTranslate[k] = {" " .. a, b .. " "}
    end

    function syntax.GetFunctionForPostfixOperator(token)
        return syntax.PostfixOperatorFunctionTranslate[token.value]
    end            
end

-- optimize lookup if we have ffi
local ffi = jit and require("ffi")

if ffi then
    for key, func in pairs(syntax) do

        if key:sub(1, 2) == "Is" then
            local map = ffi.new("uint8_t[256]", 0)

            for i = 0, 255 do
                if func(i) then
                    map[i] = 1
                end
            end
            syntax[key] = function(i) return map[i] == 1 end
        end
    end
end

do -- grammar rules
    function syntax.IsValue(token)
        if token.type == "number" or token.type == "string" then
            return true
        end

        if syntax.IsKeywordValue(token) then
            return true
        end

        if syntax.IsKeyword(token) then
            return false
        end

        if token.type == "letter" then
            return true
        end

        return false
    end

    function syntax.IsTypeValue(token)
        if token.type == "number" or token.type == "string" or token.value == "function" then
            return true
        end

        if syntax.IsKeywordValue(token) then
            return true
        end

        if syntax.IsKeyword(token) then
            return false
        end

        if token.type == "letter" then
            return true
        end

        return false
    end

    function syntax.GetTokenType(tk)
        if tk.type == "letter" and syntax.IsKeyword(tk) then
            return "keyword"
        elseif tk.type == "symbol" then
            if syntax.IsPrefixOperator(tk) then
                return "operator_prefix"
            elseif syntax.IsPostfixOperator(tk) then
                return "operator_postfix"
            elseif syntax.GetBinaryOperatorInfo(tk) then
                return "operator_binary"
            end
        end
        return tk.type
    end

    do
        local function build_lookup(tbl, func_name)
            if not tbl then return end

            local lookup = {}

            for priority, group in ipairs(tbl) do
                for _, token in ipairs(group) do
                    if token:sub(1, 1) == "R" then
                        lookup[token:sub(2)] = {left_priority = priority + 1, right_priority = priority}
                    else
                        lookup[token] = {left_priority = priority, right_priority = priority}
                    end
                end
            end

            syntax[func_name] = function(tk) return lookup[tk.value] end
        end

        build_lookup(syntax.BinaryOperators, "GetBinaryOperatorInfo")
        build_lookup(syntax.BinaryTypeOperators, "GetBinaryTypeOperatorInfo")
    end

    do
        local function build_lookup(tbl, func_name)
            if not tbl then return end

            local lookup = {}
            for _, v in pairs(tbl) do
                lookup[v] = v
            end

            syntax[func_name] = function(token) return lookup[token.value] ~= nil end
        end

        build_lookup(syntax.PrimaryBinaryOperators, "IsPrimaryBinaryOperator")
        build_lookup(syntax.PrefixOperators, "IsPrefixOperator")
        build_lookup(syntax.PostfixOperators, "IsPostfixOperator")
        build_lookup(syntax.Keywords, "IsKeyword")
        build_lookup(syntax.KeywordValues, "IsKeywordValue")

        build_lookup(syntax.PrimaryBinaryTypeOperators, "IsPrimaryBinaryTypeOperator")
        build_lookup(syntax.PrefixTypeOperators, "IsPrefixTypeOperator")
        build_lookup(syntax.PostfixTypeOperators, "IsPostfixTypeOperator")
    end
end