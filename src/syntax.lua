local syntax = {}

syntax.UTF8 = true

syntax.SymbolCharacters = {
    ".", ",", ":", ";",
    "(", ")", "{", "}", "[", "]",
    "=", "::", "\"", "'", "`",
}

syntax.Keywords = {
    "and", "break", "do", "else", "elseif", "end",
    "false", "for", "function", "interface", "if", "in", "of", "local",
    "nil", "not", "or", "repeat", "return", "then", "as", "@",
    "...", "async"
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
    "!",
}

syntax.Operators = {
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

syntax.OperatorFunctions = {
    [">>"] = "bit.rshift",
    ["<<"] = "bit.lshift",
    ["|"] = "bit.bor",
    ["&"] = "bit.band",
    ["//"] = "math.floordiv",
    ["~"] = "bit.bxor",
}

syntax.UnaryOperatorFunctions = {
    ["~"] = "bit.bnot",
}

-- temp
function math.floordiv(a, b)
    return math.floor(a / b)
end

if syntax.UTF8 then
    local utf8totable
    do
        local band = bit.band
        local bor = bit.bor
        local rshift = bit.rshift
        local lshift = bit.lshift
        local math_floor = math.floor
        local string_char = string.char
        local UTF8_ACCEPT = 0

        local utf8d =  {
            -- The first part of the table maps bytes to character classes that
            -- to reduce the size of the transition table and create bitmasks.
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
            1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,  9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
            7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
            8,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
            10,3,3,3,3,3,3,3,3,3,3,3,3,4,3,3, 11,6,6,6,5,8,8,8,8,8,8,8,8,8,8,8,

            -- The second part is a transition table that maps a combination
            -- of a state of the automaton and a character class to a state.
            0,12,24,36,60,96,84,12,12,12,48,72, 12,12,12,12,12,12,12,12,12,12,12,12,
            12, 0,12,12,12,12,12, 0,12, 0,12,12, 12,24,12,12,12,12,12,24,12,24,12,12,
            12,12,12,12,12,12,12,24,12,12,12,12, 12,24,12,12,12,12,12,12,12,24,12,12,
            12,12,12,12,12,12,12,36,12,36,12,12, 12,36,12,12,12,12,12,36,12,36,12,12,
            12,36,12,12,12,12,12,12,12,12,12,12,
        }

        utf8totable = function(str)
            local state = UTF8_ACCEPT
            local codepoint = 0

            local out = {}
            local out_i = 1

            for i = 1, #str do
                local byte = str:byte(i)
                local ctype = utf8d[byte + 1]

                if state ~= UTF8_ACCEPT then
                    codepoint = bor(band(byte, 0x3f), lshift(codepoint, 6))
                else
                    codepoint = band(rshift(0xff, ctype), byte)
                end

                state = utf8d[256 + state + ctype + 1]

                if state == UTF8_ACCEPT then
                    if codepoint > 0xffff then
                        codepoint = lshift(((0xD7C0 + rshift(codepoint, 10)) - 0xD7C0), 10) + (0xDC00 + band(codepoint, 0x3ff)) - 0xDC00
                    end

                    if codepoint <= 127 then
                        out[out_i] = string_char(codepoint)
                    elseif codepoint < 2048 then
                        out[out_i] = string_char(
                            192 + codepoint / 64,
                            128 + band(codepoint, 63)
                        )
                    elseif codepoint < 65536 then
                        out[out_i] = string_char(
                            224 + codepoint / 4096,
                            128 + band(math_floor(codepoint / 64), 63),
                            128 + band(codepoint, 63)
                        )
                    elseif codepoint < 2097152 then
                        out[out_i] = string_char(
                            240 + codepoint / 262144,
                            128 + band(math_floor(codepoint / 4096), 63),
                            128 + band(math_floor(codepoint / 64), 63),
                            128 + band(codepoint, 63)
                        )
                    else
                        out[out_i] = ""
                    end

                    out_i = out_i + 1
                end
            end
            return out
        end
    end


    local config = {}

	-- This is needed for UTF8. Assume everything is a letter if it's not any of the other types.
	config.FallbackCharacterType = "letter"

	function config.OnInitialize(tk, str)
		tk.code = utf8totable(str)
		tk.code_length = #tk.code
		tk.tbl_cache = {}
	end
	function config.GetLength(tk)
		return tk.code_length
	end
	function config.GetCharOffset(tk, i)
		return tk.code[tk.i + i] or ""
	end

	local table_concat = table.concat
	function config.GetCharsRange(tk, start, stop)
		local length = stop-start

		if not tk.tbl_cache[length] then
			tk.tbl_cache[length] = {}
		end
		local str = tk.tbl_cache[length]

		local str_i = 1
		for i = start, stop do
			str[str_i] = tk.code[i] or ""
			str_i = str_i + 1
		end
		return table_concat(str)
	end

    syntax.TokenizerSetup = config
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

    for _, group in ipairs(syntax.Operators) do
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

    for char, type in pairs(syntax.CharacterMap) do
        if type == "symbol" then
            syntax.SymbolLookup[char] = true
            do -- this triggers symbol lookup. For example it adds "~" from "~=" so that "~" is a symbol
                local first_char = string.sub(char, 1, 1)
                if not syntax.CharacterMap[first_char] then
                    syntax.CharacterMap[first_char] = "symbol"
                end
            end
            syntax.LongestSymbolLength = math.max(syntax.LongestSymbolLength, #char)
        end
    end
end

do -- grammar rules
    if syntax.UTF8 then
        function syntax.GetCharacterType(char)
            return syntax.CharacterMap[char] or (syntax.TokenizerSetup.FallbackCharacterType and char:byte() > 128 and syntax.TokenizerSetup.FallbackCharacterType)
        end
    else
        function syntax.GetCharacterType(char)
            return syntax.CharacterMap[char]
        end
    end

    function syntax.IsValue(token)
        return token.type == "number" or token.type == "string" or syntax.KeywordValues[token.value]
    end

    function syntax.IsOperator(token)
        return syntax.Operators[token.value] ~= nil
    end

    function syntax.GetLeftOperatorPriority(token)
        return syntax.Operators[token.value] and syntax.Operators[token.value][1]
    end

    function syntax.GetRightOperatorPriority(token)
        return syntax.Operators[token.value] and syntax.Operators[token.value][2]
    end

    function syntax.GetFunctionForOperator(token)
        return syntax.OperatorFunctions[token.value]
    end

    function syntax.GetFunctionForUnaryOperator(token)
        return syntax.UnaryOperatorFunctions[token.value]
    end

    function syntax.IsUnaryOperator(token)
        return syntax.UnaryOperators[token.value]
    end

    function syntax.IsKeyword(token)
        return syntax.Keywords[token.value]
    end

    local temp = {}
    for priority, group in ipairs(syntax.Operators) do
        for _, token in ipairs(group) do
            if token:sub(1, 1) == "R" then
                temp[token:sub(2)] = {priority + 1, priority}
            else
                temp[token] = {priority, priority}
            end
        end
    end
    syntax.Operators = temp

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