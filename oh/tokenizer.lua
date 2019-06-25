local oh = ...
local util = require("oh.util")

local META

do
    META = {}
    META.__index = META

    -- This is needed for UTF8. Assume everything is a letter if it's not any of the other types.
    META.FallbackCharacterType = "letter"

    function META:OnInitialize(str)
       if type(str) == "table" then
            self.code = str
            self.code_length = #str
        else
            self.code = util.UTF8ToTable(str)
            self.code_length = #self.code
        end
        self.tbl_cache = {}
    end
    function META:GetLength()
        return self.code_length
    end
    function META:GetCharOffset(i)
        return self.code[self.i + i] or ""
    end

    local table_concat = table.concat
    function META:GetCharsRange(start, stop)
        if stop < self.code_length then
            return table_concat(self.code, nil, start, stop)
        end

        local str = {}

        local str_i = 1
        for i = start, stop do
            str[str_i] = self.code[i] or ""
            str_i = str_i + 1
        end

        return table_concat(str)
    end

    function META:GetCurrentChar()
        return self.code[self.i] or ""
    end

    function META:GetCharsOffset(length)
        return self:GetCharsRange(self.i, self.i + length)
    end

    function META:StringMatches(str, lower)
        if lower then
            for i = 1, #str do
                if self.code[self.i + i - 1]:lower() ~= str:sub(i, i) then
                    return false
                end
            end
        else
            for i = 1, #str do
                if self.code[self.i + i - 1] ~= str:sub(i, i) then
                    return false
                end
            end
        end
        return true
    end

    function META:GetCharType(char)
        return oh.syntax.GetCharacterType(char) or (self.FallbackCharacterType and char:byte() > 128 and self.FallbackCharacterType)
    end

    function META:ReadChar()
        local char = self:GetCurrentChar()
        self.i = self.i + 1
        return char
    end

    function META:ReadCharByte()
        local b = self:GetCurrentChar()
        self.i = self.i + 1
        return b
    end

    function META:Advance(len)
        self.i = self.i + len
    end

    function META:Error(msg, start, stop)
        if self.OnError then
            self:OnError(msg, start or self.i, stop or self.i)
        end
    end

    local TOKEN = {}
    function TOKEN:__index(key)
        if key == "value" then
            return self.tk:GetCharsRange(self.start, self.stop)
        end
    end

    local setmetatable = setmetatable

    function META:NewToken(type, start, stop)
        --return setmetatable({tk = self, type = type, start = start, stop = stop, whitespace = whitespace}, TOKEN)
        return {
            type = type,
            start = start,
            stop = stop,
            value = self:GetCharsRange(start, stop),
        }
    end

    local function ReadLiteralString(self, multiline_comment)
        local start = self.i

        local c = self:ReadChar()
        if c ~= "[" then
            if multiline_comment then return true end
            return nil, "expected "..oh.QuoteToken("[").." got " .. oh.QuoteToken(c)
        end

        if self:GetCurrentChar() == "=" then
            self:Advance(1)

            for _ = self.i, self.code_length do
                if self:GetCurrentChar() ~= "=" then
                    break
                end
                self:Advance(1)
            end
        end

        c = self:ReadChar()

        if c ~= "[" then
            if multiline_comment then return false end
            return nil, "expected " .. oh.QuoteToken(self.get_code_char_range(self, start, self.i - 1) .. "[") .. " got " .. oh.QuoteToken(self.get_code_char_range(self, start, self.i - 1) .. c)
        end

        local length = self.i - start

        if length < 2 then return nil end

        local closing = "]" .. string.rep("=", length - 2) .. "]"
        local found = false
        for _ = self.i, self.code_length do
            if self:StringMatches(closing) then
                self:Advance(length)
                found = true
                break
            end
            self:Advance(1)
        end

        if not found then
            return nil, "expected "..oh.QuoteToken(closing).." reached end of code"
        end

        return true
    end

    do -- whitespace
        do
            function META:IsMultilineComment()
                return self:StringMatches("--[=") or self:StringMatches("--[[")
            end

            function META:ReadMultilineComment()
                local start = self.i
                self:Advance(2)

                local ok, err = ReadLiteralString(self, true)

                if not ok then
                    if err then
                        self.i = start + 2
                        self:Error("unterminated multiline comment: " .. err, start, start + 1)
                    else
                        self.i = start
                        return self:ReadLineComment()
                    end
                end


                return "multiline_comment"
            end
        end

        do

            local function LINE_COMMENT(str, name, func_name)
                META["Is" .. func_name] = function(self)
                    return self:StringMatches(str)
                end

                META["Read" .. func_name] = function(self)
                    self:Advance(#str)

                    for _ = self.i, self.code_length do
                        if self:ReadChar() == "\n" or self.i-1 == self.code_length then
                            break
                        end
                    end

                    return name
                end
            end

            LINE_COMMENT("--", "line_comment", "LineComment")
        end

        do
            function META:IsSpace()
                return self:GetCharType(self:GetCurrentChar()) == "space"
            end

            function META:ReadSpace()
                for _ = self.i, self.code_length do
                    self:Advance(1)
                    if self:GetCharType(self:GetCurrentChar()) ~= "space" then
                        break
                    end
                end

                return "space"
            end
        end
    end

    do -- other
        do
            function META:IsEndOfFile()
                return self.i > self.code_length
            end

            function META:ReadEndOfFile()
                -- nothing to capture, but remaining whitespace will be added
                return "end_of_file"
            end
        end

        do
            function META:IsMultilineString()
                return self:StringMatches("[=") or self:StringMatches("[[")
            end

            function META:ReadMultilineString()
                local start = self.i
                local ok, err = ReadLiteralString(self, true)

                if not ok then
                    self:Error("unterminated multiline string: " .. err, start, start + 1)
                    return
                end

                return "string"
            end
        end

        do
            local string_lower = string.lower
            local allowed = {
                ["a"] = true,
                ["b"] = true,
                ["c"] = true,
                ["d"] = true,
                ["e"] = true,
                ["f"] = true,
                ["p"] = true,
                ["_"] = true,
                ["."] = true,
            }

            local pow_letter = "p"
            local plus_sign = "+"
            local minus_sign = "-"

            local legal_number_annotations = {"ull", "ll", "ul", "i"}
            table.sort(legal_number_annotations, function(a, b) return #a > #b end)

            function META:ReadNumberAnnotations()
                for _, annotation in ipairs(legal_number_annotations) do
                    local len = #annotation
                    if self:StringMatches(annotation, true) then
                        local t = self:GetCharType(self:GetCharOffset(len))

                        if t == "space" or t == "symbol" then
                            self:Advance(len)
                            return true
                        end
                    end
                end
            end

            function META:IsNumber()
                if self:GetCurrentChar() == "." and self:GetCharType(self:GetCharOffset(1)) == "number" then
                    return true
                end

                return self:GetCharType(self:GetCurrentChar()) == "number"
            end

            function META:ReadHexNumber()
                self:Advance(2)

                local pow = false

                for _ = self.i, self.code_length do
                    if self:ReadNumberAnnotations() then return "number" end

                    local char = string_lower(self:GetCurrentChar())
                    local t = self:GetCharType(self:GetCurrentChar())

                    if char == pow_letter then
                        if not pow then
                            pow = true
                        else
                            self:Error("malformed number: pow character can only be used once")
                            return false
                        end
                    end

                    if not (t == "number" or allowed[char] or ((char == plus_sign or char == minus_sign) and string_lower(self:GetCharOffset(-1)) == pow_letter) ) then
                        if not t or t == "space" or t == "symbol" then
                            return "number"
                        elseif char == "symbol" or t == "letter" then
                            self:Error("malformed number: invalid character "..oh.QuoteToken(char)..". only "..oh.QuoteTokens("abcdef0123456789_").." allowed after hex notation")
                            return false
                        end
                    end

                    self:Advance(1)
                end

                return "number"
            end

            function META:ReadBinaryNumber()
                self:Advance(2)

                for _ = self.i, self.code_length do
                    local char = string_lower(self:GetCurrentChar())
                    local t = self:GetCharType(self:GetCurrentChar())

                    if char ~= "1" and char ~= "0" and char ~= "_" then
                        if not t or t == "space" or t == "symbol" then
                            return "number"
                        elseif char == "symbol" or t == "letter" or (char ~= "0" and char ~= "1") then
                            self:Error("malformed number: only "..oh.QuoteTokens("01_").." allowed after binary notation")
                            return false
                        end
                    end

                    self:Advance(1)
                end

                return "number"
            end

            function META:ReadDecimalNumber()
                local found_dot = false
                local exponent = false

                local start = self.i

                for _ = self.i, self.code_length do
                    local t = self:GetCharType(self:GetCurrentChar())
                    local char = self:GetCurrentChar()

                    if exponent then
                        if char ~= "-" and char ~= "+" and t ~= "number" then
                            self:Error("malformed number: invalid character " .. oh.QuoteToken(char) .. ". only "..oh.QuoteTokens("+-0123456789").." allowed after exponent", start, self.i)
                            return false
                        elseif char ~= "-" and char ~= "+" then
                            exponent = false
                        end
                    elseif t ~= "number" then
                        if t == "letter" then
                            start = self.i
                            if string_lower(char) == "e" then
                                exponent = true
                            elseif self:ReadNumberAnnotations() then
                                return "number"
                            else
                            -- self:Error("malformed number: invalid character " .. oh.QuoteToken(char) .. ". only " .. oh.QuoteTokens(legal_number_annotations) .. " allowed after a number", start, self.i)
                                return "number"
                            end
                        elseif not found_dot and char == "." then
                            found_dot = true
                        elseif t == "space" or t == "symbol" then
                            return "number"
                        end
                    end

                    self:Advance(1)
                end

                return "number"
            end

            function META:ReadNumber()
                local s = string_lower(self:GetCharOffset(1))
                if s == "x" then
                    return self:ReadHexNumber()
                elseif s == "b" then
                    return self:ReadBinaryNumber()
                end

                return self:ReadDecimalNumber()
            end
        end
    end

    do
        local escape_character = [[\]]
        local quotes = {
            Double = [["]],
            Single = [[']],
        }

        for name, quote in pairs(quotes) do
            META["Is" .. name .. "String"] = function(self)
                return self:GetCurrentChar() == quote
            end

            local key = "string_escape_" .. name
            local function escape(self, c)
                if self[key] then

                    if c == "z" and self:GetCurrentChar() ~= quote then
                        self:ReadSpace(self)
                    end

                    self[key] = false
                    return "string"
                end

                if c == escape_character then
                    self[key] = true
                end

                return false
            end

            META["Read" .. name .. "String"] = function(self)
                local start = self.i
                self:Advance(1)

                for _ = self.i, self.code_length do
                    local char = self:ReadCharByte()

                    if not escape(self, char) then

                        if char == "\n" then
                            self:Advance(-1)
                            self:Error("unterminated " .. name:lower() .. " quote", start, self.i - 1)
                            return false
                        end

                        if char == quote then
                            return "string"
                        end
                    end
                end

                self:Error("unterminated " .. name:lower() .. " quote: reached end of file", start, self.i - 1)

                return false
            end
        end
    end

    do
        function META:IsLetter()
            return self:GetCharType(self:GetCurrentChar()) == "letter"
        end

        function META:ReadLetter()
            local start = self.i
            self:Advance(1)
            for _ = self.i, self.code_length do
                local t = self:GetCharType(self:GetCurrentChar())
                if t == "space" or not (t == "letter" or (t == "number" and self.i ~= start)) then
                    break
                end
                self:Advance(1)
            end

            return "letter"
        end
    end

    do
        function META:IsSymbol()
            return self:GetCharType(self:GetCurrentChar()) == "symbol"
        end

        function META:ReadSymbol()

            local node = oh.syntax.SymbolLookup
            for i = 0, oh.syntax.LongestSymbolLength - 1 do
                local found = node[self:GetCharOffset(i)]
                if not found then break end

                node = found
            end

            if node.DONE then
                self:Advance(node.DONE.length)
                return "symbol"
            end
        end
    end

    do
        function META:IsShebang()
            return self.i == 1 and self:GetCurrentChar() == "#"
        end

        function META:ReadShebang()
            for _ = self.i, self.code_length do
                if self:ReadChar() == "\n" then
                    return "shebang"
                end
            end
        end
    end

    function META:ReadWhiteSpace()
        if
        self:IsSpace() then                 return self:ReadSpace() elseif
        self:IsMultilineComment() then      return self:ReadMultilineComment() elseif
        self:IsLineComment() then           return self:ReadLineComment() elseif
        false then end
    end

    function META:ReadNonWhiteSpace()
        if
        self:IsEndOfFile() then             return self:ReadEndOfFile() elseif
        self:IsMultilineString() then       return self:ReadMultilineString() elseif
        self:IsNumber() then                return self:ReadNumber() elseif
        self:IsSingleString() then          return self:ReadSingleString() elseif
        self:IsDoubleString() then          return self:ReadDoubleString() elseif
        self:IsLetter() then                return self:ReadLetter() elseif
        self:IsSymbol() then                return self:ReadSymbol() elseif
        false then end

        self:Advance(1)
        return "unknown"
    end

    function META:ReadToken()

        if self:IsShebang() then
            self:ReadShebang()
            local tk = self:NewToken("shebang", 1, self.i - 1)
            tk.whitespace = {}
            return tk
        end

        local wbuffer = {}

        for i = 1, self.code_length do
            local start = self.i
            local type = self:ReadWhiteSpace()
            if not type then
                break
            end

            wbuffer[i] = self:NewToken(type, start, self.i - 1)
        end

        local start = self.i
        local type = self:ReadNonWhiteSpace()
        local stop = self.i - 1

        local tk = self:NewToken(type or "unknown", start, stop)
        tk.whitespace = wbuffer
        return tk
    end

    function META:GetTokens()
        self.i = 1

        local tokens = {}
        local tokens_i = 1

        for _ = self.i, self.code_length do
            local token = self:ReadToken()

            tokens[tokens_i] = token
            tokens_i = tokens_i + 1

            if token.type == "end_of_file" then break end
        end

        return tokens
    end

    function META:ResetState()
        self.code_length = self:GetLength()
        self.whitespace_buffer = {}
        self.whitespace_buffer_i = 1
        self.i = 1
    end
end

local Tokenizer = function(code, on_error, capture_whitespace)
    local tk = setmetatable({}, META)

    if capture_whitespace == nil then
        tk.capture_whitespace = true
    end

    tk.OnError = on_error or false

    tk:OnInitialize(code, on_error)

    return tk
end

function oh.Tokenizer(code)
    local self = Tokenizer(code)
    self:ResetState()
    return self
end