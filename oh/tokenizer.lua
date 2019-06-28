local oh = ...
local util = require("oh.util")

local B = string.byte

local META

do
    META = {}
    META.__index = META

    -- This is needed for UTF8. Assume everything is a letter if it's not any of the other types.
    META.FallbackCharacterType = "letter"

    function META:OnInitialize(str)
        str = util.RemoveBOMHeader(str)
        self.code = str
        self.code_length = #str
    end
    function META:GetLength()
        return self.code_length
    end

    function META:GetChars(start, stop)
        return self.code:sub(start, stop)
    end

    function META:GetChar(offset)
        if offset then
            return self.code:byte(self.i + offset)
        end
        return self.code:byte(self.i)
    end

    function META:StringMatches(str)
        for i = 1, #str do
            if self:GetChar(i-1) ~= str:byte(i) then
                return false
            end
        end
        return true
    end

    function META:GetCharType(char)
        return oh.syntax.GetCharacterType(char)
    end

    function META:ReadChar()
        local char = self:GetChar()
        self.i = self.i + 1
        return char
    end

    function META:Advance(len)
        self.i = self.i + len
    end

    function META:IsValue(what, offset)
        if offset then
            return self:GetChar(offset) == B(what)
        end
        return self:GetChar() == B(what)
    end

    function META:IsType(what, offset)
        if offset then
            return self:GetCharType(self:GetChar(offset)) == what
        end
        return self:GetCharType(self:GetChar()) == what
    end

    function META:Error(msg, start, stop)
        if self.OnError then
            self:OnError(msg, start or self.i, stop or self.i)
        end
    end

    local TOKEN = {}
    function TOKEN:__index(key)
        if key == "value" then
            return self.tk:GetChars(self.start, self.stop)
        end
    end

    --local setmetatable = setmetatable

    function META:NewToken(type, start, stop)
        --return setmetatable({tk = self, type = type, start = start, stop = stop, whitespace = whitespace}, TOKEN)
        return {
            type = type,
            start = start,
            stop = stop,
            value = self:GetChars(start, stop),
        }
    end

    local function ReadLiteralString(self, multiline_comment)
        local start = self.i

        self:Advance(1)

        if self:IsValue("=") then
            for _ = self.i, self:GetLength() do
                self:Advance(1)
                if not self:IsValue("=") then
                    break
                end
            end
        end

        if not self:IsValue("[") then
            if multiline_comment then return false end
            return nil, "expected " .. oh.QuoteToken(self:GetChars(start, self.i - 1) .. "[") .. " got " .. oh.QuoteToken(self:GetChars(start, self.i))
        end

        self:Advance(1)

        local length = self.i - start
        local closing = "]" .. string.rep("=", length - 2) .. "]"

        for _ = self.i, self:GetLength() do
            if self:StringMatches(closing) then
                self:Advance(length)
                return true
            end
            self:Advance(1)
        end

        return nil, "expected "..oh.QuoteToken(closing).." reached end of code"
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

                    for _ = self.i, self:GetLength() do
                        if self:ReadChar() == B"\n" then
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
                return self:IsType("space")
            end

            function META:ReadSpace()
                for _ = self.i, self:GetLength() do
                    self:Advance(1)
                    if not self:IsType("space") then
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
                return self.i > self:GetLength()
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
                local ok, err = ReadLiteralString(self, false)

                if not ok then
                    self:Error("unterminated multiline string: " .. err, start, start + 1)
                    return
                end

                return "string"
            end
        end

        do
            local function generate_map(str)
                local out = {}
                for i = 1, #str do
                    out[str:byte(i)] = true
                end
                return out
            end

            local allowed_hex = generate_map("1234567890abcdefABCDEF")

            function META:ReadNumberAnnotations(what)
                if what == "hex" then
                    if self:IsNumberPow() then
                        return self:ReadNumberPowExponent("pow")
                    end
                elseif what == "decimal" then
                    if self:IsNumberExponent() then
                        return self:ReadNumberPowExponent("exponent")
                    end
                end

                return oh.syntax.ReadLongestNumberAnnotation(self)
            end

            function META:IsNumberExponent()
                return self:IsValue("e") or self:IsValue("E")
            end

            function META:IsNumberPow()
                return self:IsValue("p") or self:IsValue("P")
            end

            function META:ReadNumberPowExponent(what)
                self:Advance(1)
                if self:IsValue("+") or self:IsValue("-") then
                    self:Advance(1)
                    if not self:IsType("number") then
                        self:Error("malformed " .. what .. " expected number, got " .. string.char(self:GetChar()), self.i - 2)
                        return false
                    end
                end
                for _ = self.i, self:GetLength() do
                    if not self:IsType("number") then
                        break
                    end
                    self:Advance(1)
                end

                return true
            end

            function META:ReadHexNumber()
                self:Advance(2)

                local dot = false

                for _ = self.i, self:GetLength() do
                    if self:IsValue("_") then self:Advance(1) end

                    if self:IsValue(".") then
                        if dot then
                            --self:Error("dot can only be placed once")
                            return
                        end
                        dot = true
                        self:Advance(1)
                    end

                    if self:ReadNumberAnnotations("hex") then
                        break
                    end

                    if allowed_hex[self:GetChar()] then
                        self:Advance(1)
                    elseif self:IsType("symbol") or self:IsType("space") then
                        break
                    elseif self:GetChar() ~= "" then
                        self:Error("malformed number "..string.char(self:GetChar()).." in hex notation")
                        return
                    end
                end

                return "number"
            end

            function META:ReadBinaryNumber()
                self:Advance(2)

                for _ = self.i, self:GetLength() do
                    if self:IsValue("_") then self:Advance(1) end

                    if self:IsValue("1") or self:IsValue("0") then
                        self:Advance(1)
                    elseif self:IsType("symbol") or self:IsType("space") then
                        break
                    elseif self:GetChar() ~= "" then
                        self:Error("malformed number "..string.char(self:GetChar()).." in binary notation")
                        return
                    end

                    if self:ReadNumberAnnotations("binary") then
                        break
                    end
                end

                return "number"
            end

            function META:ReadDecimalNumber()
                local dot = false

                for _ = self.i, self:GetLength() do
                    if self:IsValue("_") then self:Advance(1) end

                    if self:IsValue(".") then
                        if dot then
                            --self:Error("dot can only be placed once")
                            return
                        end
                        dot = true
                        self:Advance(1)
                    end

                    if self:ReadNumberAnnotations("decimal") then
                        break
                    end

                    if self:IsType("number") then
                        self:Advance(1)
                    elseif self:IsType("symbol") or self:IsType("space") then
                        break
                    else--if self:GetChar() ~= "" then
                        --self:Error("malformed number "..self:GetChar().." in hex notation")
                        return
                    end
                end

                return "number"
            end

            function META:IsNumber()
                return self:IsType("number") or (self:IsValue(".") and self:IsType("number", 1))
            end

            function META:ReadNumber()
                if self:IsValue("x", 1) or self:IsValue("X", 1) then
                    return self:ReadHexNumber()
                elseif self:IsValue("b", 1) or self:IsValue("B", 1) then
                    return self:ReadBinaryNumber()
                end

                return self:ReadDecimalNumber()
            end
        end
    end

    do
        local escape_character = B[[\]]
        local quotes = {
            Double = [["]],
            Single = [[']],
        }

        for name, quote in pairs(quotes) do
            META["Is" .. name .. "String"] = function(self)
                return self:IsValue(quote)
            end

            local key = "string_escape_" .. name
            local function escape(self, c)
                if self[key] then

                    if c == B"z" and not self:IsValue(quote) then
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

                for _ = self.i, self:GetLength() do
                    local char = self:ReadChar()

                    if not escape(self, char) then

                        if char == B"\n" then
                            self:Advance(-1)
                            self:Error("unterminated " .. name:lower() .. " quote", start, self.i - 1)
                            return false
                        end

                        if char == B(quote) then
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
            return self:IsType("letter")
        end

        function META:ReadLetter()
            for _ = self.i, self:GetLength() do
                self:Advance(1)
                if self:IsType("space") or not self:IsType("letter") and not self:IsType("number") then
                    break
                end
            end

            return "letter"
        end
    end

    do
        function META:IsSymbol()
            return self:IsType("symbol")
        end

        function META:ReadSymbol()
            return oh.syntax.ReadLongestSymbol(self)
        end
    end

    do
        function META:IsShebang()
            return self.i == 1 and self:IsValue("#")
        end

        function META:ReadShebang()
            for _ = self.i, self:GetLength() do
                if self:ReadChar() == B"\n" then
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

        for i = 1, self:GetLength() do
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

        for _ = self.i, self:GetLength() do
            local token = self:ReadToken()

            tokens[tokens_i] = token
            tokens_i = tokens_i + 1

            if token.type == "end_of_file" then break end
        end

        return tokens
    end

    function META:ResetState()
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