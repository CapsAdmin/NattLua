--[[# 

type Token = {
    value = string,
    type = string,
}
]]

return function(syntax)
    do
        local B = string.byte

        function syntax.IsLetter(c --[[#: number]]) --[[#: boolean]]
            return
                (c >= B'a' and c <= B'z') or
                (c >= B'A' and c <= B'Z') or
                (c == B'_' or c >= 127)
        end

        function syntax.IsDuringLetter(c --[[#: number]]) --[[#: boolean]]
            return
                (c >= B'a' and c <= B'z') or
                (c >= B'0' and c <= B'9') or
                (c >= B'A' and c <= B'Z') or
                (c == B'_' or c >= 127)
        end

        function syntax.IsNumber(c --[[#: number]]) --[[#: boolean]]
            return (c >= B'0' and c <= B'9')
        end

        function syntax.IsSpace(c --[[#: number]]) --[[#: boolean]]
            return c > 0 and c <= 32
        end

        function syntax.IsSymbol(c --[[#: number]]) --[[#: boolean]]
            return c ~= B'_' and (
                (c >= B'!' and c <= B'/') or
                (c >= B':' and c <= B'@') or
                (c >= B'[' and c <= B'`') or
                (c >= B'{' and c <= B'~')
            )
        end
    end

    local symbols = {}

    local function add_symbols(tbl --[[#: {[number] = string}]])
        if not tbl then return end

        for _, symbol in pairs(tbl) do
            if symbol:find("%p") then
                table.insert(symbols, symbol)
            end
        end
    end

    do -- extend the symbol characters from grammar rules
        local function add_binary_symbols(tbl --[[#: {[number] = {[number] = string}}]])
            if not tbl then return end

            for _, group in ipairs(tbl) do
                for _, token in ipairs(group) do
                    if token:find("%p") then
                        if token:sub(1, 1) == "R" then
                            token = token:sub(2)
                        end

                        table.insert(symbols, token)
                    end
                end
            end
        end

        add_binary_symbols(syntax.BinaryOperators)
        add_symbols(syntax.PrefixOperators)
        add_symbols(syntax.PostfixOperators)
        add_symbols(syntax.PrimaryBinaryOperators)

        for _, str in ipairs(syntax.SymbolCharacters) do
            table.insert(symbols, str)
        end

        function syntax.GetSymbols()
            return symbols
        end
    end

    do
        local lookup = {}

        for k, v in pairs(syntax.BinaryOperatorFunctionTranslate or {}) do
            local a,b,c = v:match("(.-)A(.-)B(.*)")
            lookup[k] = {" " .. a, b, c .. " "}
        end

        function syntax.GetFunctionForBinaryOperator(token --[[#: Token]])
            return lookup[token.value]
        end
    end

    do
        local lookup = {}

        for k, v in pairs(syntax.PrefixOperatorFunctionTranslate or {}) do
            local a, b = v:match("^(.-)A(.-)$")
            lookup[k] = {" " .. a, b .. " "}
        end

        function syntax.GetFunctionForPrefixOperator(token --[[#: Token]])
            return lookup[token.value]
        end
    end


    do
        local lookup = {}

        for k, v in pairs(syntax.PostfixOperatorFunctionTranslate or {}) do
            local a, b = v:match("^(.-)A(.-)$")
            lookup[k] = {" " .. a, b .. " "}
        end

        function syntax.GetFunctionForPostfixOperator(token --[[#: Token]])
            return lookup[token.value]
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
        function syntax.IsValue(token --[[#: Token]])
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

        function syntax.GetTokenType(tk --[[#: Token]])
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
            local lookup = {}

            for priority, group in ipairs(syntax.BinaryOperators or {}) do
                for _, token in ipairs(group) do
                    if token:sub(1, 1) == "R" then
                        lookup[token:sub(2)] = {left_priority = priority + 1, right_priority = priority}
                    else
                        lookup[token] = {left_priority = priority, right_priority = priority}
                    end
                end
            end

            function syntax.GetBinaryOperatorInfo(tk --[[#: Token]])
                return lookup[tk.value]
            end
        end

        do
            local function build_lookup(tbl, func_name)
                local lookup = {}

                for _, v in pairs(tbl or {}) do
                    lookup[v] = v
                end

                syntax[func_name] = function(token --[[#: Token]]) --[[#: boolean]] 
                    return lookup[token.value] ~= nil 
                end
            end

            build_lookup(syntax.PrimaryBinaryOperators, "IsPrimaryBinaryOperator")
            build_lookup(syntax.PrefixOperators, "IsPrefixOperator")
            build_lookup(syntax.PostfixOperators, "IsPostfixOperator")
            build_lookup(syntax.KeywordValues, "IsKeywordValue")

            do
                local keywords = {}

                for _, str in ipairs(syntax.KeywordValues) do
                    table.insert(keywords, str)
                end
                
                for _, str in ipairs(syntax.Keywords) do
                    table.insert(keywords, str)
                end
                
                add_symbols(keywords)

                build_lookup(keywords, "IsKeyword")
            end
        end
    end
end