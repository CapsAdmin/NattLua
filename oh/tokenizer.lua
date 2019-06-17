local oh = ...
local util = require("oh.util")

local META

do
    META = {}
    META.__index = META

    -- This is needed for UTF8. Assume everything is a letter if it's not any of the other types.
    META.FallbackCharacterType = "letter"

    function META:OnInitialize(str)
        self.code = util.UTF8ToTable(str)
        self.code_length = #self.code
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
        local length = stop-start

        if not self.tbl_cache[length] then
            self.tbl_cache[length] = {}
        end
        local str = self.tbl_cache[length]

        local str_i = 1
        for i = start, stop do
            str[str_i] = self.code[i] or ""
            str_i = str_i + 1
        end
        return table_concat(str)
    end

    function META:GetCurrentChar()
        return self:GetCharOffset(0)
    end

    function META:GetCharsOffset(length)
        return self:GetCharsRange(self.i, self.i + length)
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

    function META:NewToken(tbl)
        tbl.tk = self
        return setmetatable(tbl, TOKEN)
    end

    function META:BufferWhitespace(type, start, stop)
        self.whitespace_buffer[self.whitespace_buffer_i] = self:NewToken({
            type = type,
            start = start == 1 and 0 or start,
            stop = stop,
        })

        self.whitespace_buffer_i = self.whitespace_buffer_i + 1
    end

    local function CaptureLiteralString(self, multiline_comment)
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
            if multiline_comment then return true end
            return nil, "expected " .. oh.QuoteToken(self.get_code_char_range(self, start, self.i - 1) .. "[") .. " got " .. oh.QuoteToken(self.get_code_char_range(self, start, self.i - 1) .. c)
        end

        local length = self.i - start

        if length < 2 then return nil end

        local closing = "]" .. string.rep("=", length - 2) .. "]"
        local found = false
        for _ = self.i, self.code_length do
            if self:GetCharsOffset(length - 1) == closing then
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
                local str = self:GetCharsOffset(3)
                return str == "--[=" or str == "--[["
            end

            function META:CaptureMultilineComment(start)
                self:Advance(2)

                local ok, err = CaptureLiteralString(self, true)

                if not ok then
                    self.i = start + 2
                    self:Error("unterminated multiline comment: " .. err, start, start + 1)
                end

                self:BufferWhitespace("multiline_comment", start, self.i - 1)
            end
        end

        do
            function META:IsGLuaMultilineComment()
                return self:GetCharsOffset(1) == "/*"
            end

            function META:CaptureGLuaMultilineComment(start)
                self:Advance(2)

                for _ = self.i, self.code_length do
                    self:Advance(1)
                    if self:GetCharsOffset(1) == "*/" then
                        self:Advance(2)
                        break
                    end
                end

                self:BufferWhitespace("glua_multiline_comment", start, self.i - 1)
            end
        end

        do

            local function LINE_COMMENT(str, name, func_name)
                META["Is" .. func_name] = function(self)
                    return self:GetCharsOffset(#str - 1) == str
                end

                META["Capture" .. func_name] = function(self, start)
                    self:Advance(#str)

                    for _ = self.i, self.code_length do
                        if self:ReadChar() == "\n" or self.i-1 == self.code_length then
                            break
                        end
                    end

                    self:BufferWhitespace(name, start, self.i - 1)
                end
            end

            LINE_COMMENT("--", "line_comment", "LineComment")
            LINE_COMMENT("//", "glua_line_comment", "GLuaLineComment")
        end

        do
            function META:IsSpace()
                return self:GetCharType(self:GetCurrentChar()) == "space"
            end

            function META:CaptureSpace(start)
                for _ = self.i, self.code_length do
                    self:Advance(1)
                    if self:GetCharType(self:GetCurrentChar()) ~= "space" then
                        break
                    end
                end

                self:BufferWhitespace("space", start, self.i - 1)
            end
        end
    end

    do -- other
        do
            function META:IsEndOfFile()
                return self.i > self.code_length
            end

            function META:CaptureEndOfFile(start)
                -- nothing to capture, but remaining whitespace will be added
                return "end_of_file"
            end
        end

        do
            function META:IsMultilineString()
                return self:GetCharsOffset(1) == "[=" or self:GetCharsOffset(1) == "[["
            end

            function META:CaptureMultilineString(start)
                local ok, err = CaptureLiteralString(self, true)

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

            function META:CaptureNumberAnnotations()
                for _, annotation in ipairs(legal_number_annotations) do
                    local len = #annotation
                    if string_lower(self:GetCharsOffset(len - 1)) == annotation then
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

            function META:CaptureHexNumber()
                self:Advance(2)

                local pow = false

                for _ = self.i, self.code_length do
                    if self:CaptureNumberAnnotations() then return "number" end

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

            function META:CaptureBinaryNumber()
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

            function META:CaptureDecimalNumber()
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
                            elseif self:CaptureNumberAnnotations() then
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

            function META:CaptureNumber(start)
                local s = string_lower(self:GetCharOffset(1))
                if s == "x" then
                    return self:CaptureHexNumber()
                elseif s == "b" then
                    return self:CaptureBinaryNumber()
                end

                return self:CaptureDecimalNumber()
            end
        end
    end

    do
        local str = "##"

        function META:IsCompilerOption()
            return self:GetCharsOffset(#str - 1) == str
        end

        function META:CaptureCompilerOption(start)
            self:Advance(#str)
            local i = self.i

            for _ = self.i, self.code_length do
                if self:ReadChar() == "\n" or self.i-1 == self.code_length then
                    local code = self:GetCharsRange(i, self.i-1)
                    if code:sub(1, 2) == "T:" then
                        local code = "local self = ...;" .. code:sub(3)
                        assert(loadstring(code))(self)
                    end
                    break
                end
            end

            return "compiler_option"
        end
    end

    do
        local str = "`"

        function META:IsLiteralString()
            return self:GetCurrentChar() == str
        end

        function META:CaptureLiteralString(start)
            self:Advance(1)

            for _ = self.i, self.code_length do
                local char = self:ReadCharByte()

                if char == str then
                    return "literal_string"
                end
            end

            self:Error("unterminated " .. str, start, self.i - 1)

            return false
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
                        self:CaptureSpace(self)
                    end

                    self[key] = false
                    return "string"
                end

                if c == escape_character then
                    self[key] = true
                end

                return false
            end

            META["Capture" .. name .. "String"] = function(self, start)
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

        function META:CaptureLetter(start)
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

        function META:CaptureSymbol()
            for len = oh.syntax.LongestSymbolLength - 1, 0, -1 do
                if oh.syntax.SymbolLookup[self:GetCharsOffset(len)] then
                    self:Advance(len + 1)
                    break
                end
            end

            return "symbol"
        end
    end

    do
        function META:IsShebang()
            return self.i == 1 and self:GetCurrentChar() == "#" and self:GetCharOffset(1) == "!"
        end

        function META:CaptureShebang()
            for _ = self.i, self.code_length do
                if self:ReadChar() == "\n" then
                    return "shebang"
                end
            end
        end
    end

    function META:CaptureToken()
        if self:IsShebang() then
            self:CaptureShebang()
            return "shebang", 1, self.i - 1, {}
        end

        for _ = self.i, self.code_length do
            if self:IsMultilineComment() then
                self:CaptureMultilineComment(self.i)
            elseif self:IsGLuaMultilineComment() then
                self:CaptureGLuaMultilineComment(self.i) -- NON LUA
            elseif self:IsLineComment() then
                self:CaptureLineComment(self.i)
            elseif self:IsGLuaLineComment() then
                self:CaptureGLuaLineComment(self.i) -- NON LUA
            elseif self:IsSpace() then
                self:CaptureSpace(self.i)
            else
                break
            end
        end

        local start = self.i
        local type
        if self:IsEndOfFile() then
            type = self:CaptureEndOfFile(start)
        elseif self:IsMultilineString() then
            type = self:CaptureMultilineString(start)
        elseif self:IsNumber() then
            type = self:CaptureNumber(start)
        elseif self:IsCompilerOption() then
            type = self:CaptureCompilerOption(start) -- NON LUA
        elseif self:IsLiteralString() then
            type = self:CaptureLiteralString(start) -- NON LUA
        elseif self:IsSingleString() then
            type = self:CaptureSingleString(start)
        elseif self:IsDoubleString() then
            type = self:CaptureDoubleString(start)
        elseif self:IsLetter() then
            type = self:CaptureLetter()
        elseif self:IsSymbol() then
            type = self:CaptureSymbol()
        end

        if type then
            local whitespace = self.whitespace_buffer
            self.whitespace_buffer = {}
            self.whitespace_buffer_i = 1
            return type, start, self.i - 1, whitespace
        end
    end

    function META:ReadToken()
        local type, start, stop, whitespace = self:CaptureToken()

        if not type then
            local start = self.i
            self:Advance(1)
            local stop = self.i - 1

            local whitespace = self.whitespace_buffer

            self.whitespace_buffer = {}
            self.whitespace_buffer_i = 1

            return "unknown", start, stop, whitespace
        end

        return type, start, stop, whitespace
    end

    function META:GetTokens()
        self.i = 1

        local tokens = {}
        local tokens_i = 1

        for _ = self.i, self.code_length do
            local type, start, stop, whitespace = self:ReadToken()

            tokens[tokens_i] = self:NewToken({
                type = type,
                start = start,
                stop = stop,
                whitespace = whitespace
            })

            if type == "end_of_file" then break end

            tokens_i = tokens_i + 1
        end

        return tokens
    end

    local function get_value(token)
        return token.tk:GetCharsRange(token.start, token.stop)
    end

    function META:ResetState()
        self.code_length = self:GetLength()
        self.whitespace_buffer = {}
        self.whitespace_buffer_i = 1
        self.i = 1

        self.get_value = get_value
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