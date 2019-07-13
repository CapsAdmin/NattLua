local syntax = require("oh.syntax")
local print_util = require("oh.print_util")
local Token = require("oh.token")

local B = string.byte

local ffi = jit and require("ffi")

if ffi then
    ffi.cdef([[
        size_t strspn( const char * str1, const char * str2 );
    ]])
end

local META = {}
META.__index = META

local function remove_bom_header(str)
    if str:sub(1, 2) == "\xFE\xFF" then
        return str:sub(3)
    elseif str:sub(1, 3) == "\xEF\xBB\xBF" then
        return str:sub(4)
    end
    return str
end

function META:OnInitialize(str)
    str = remove_bom_header(str)
    self.code = str

    if ffi then
        self.code_ptr_ref = str
        self.code_ptr = ffi.cast("const uint8_t *", self.code_ptr_ref)
    end

    self:ResetState()
end

function META:GetLength()
    return #self.code
end

if ffi then
    local ffi_string = ffi.string

    function META:GetChars(start, stop)
        return ffi_string(self.code_ptr + start - 1, (stop - start) + 1)
    end

    function META:GetChar(offset)
        if offset then
            return self.code_ptr[self.i + offset - 1]
        end
        return self.code_ptr[self.i - 1]
    end

    function META:ResetState()
        self.i = 1
    end
else
    function META:GetChars(start, stop)
        return self.code:sub(start, stop)
    end

    function META:GetChar(offset)
        if offset then
            return self.code:byte(self.i + offset) or 0
        end
        return self.code:byte(self.i) or 0
    end

    function META:ResetState()
        self.i = 1
    end
end

function META:FindNearest(str)
    local _, stop = self.code:find(str, self.i, true)

    if stop then
        return stop - self.i + 1
    end

    return false
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
    return self:IsByte(B(what), offset)
end

function META:IsByte(what, offset)
    if offset then
        return self:GetChar(offset) == what
    end
    return self:GetChar() == what
end

local function generate_lookup_function(tbl, lower)
    local copy = {}
    local done = {}

    for _, str in ipairs(tbl) do
        if not done[str] then
            table.insert(copy, str)
            done[str] = true
        end
    end

    table.sort(copy, function(a, b) return #a > #b end)

    local kernel = "return function(self)\n"

    for _, str in ipairs(copy) do
        local lua = "if "

        for i = 1, #str do
            if lower then
                lua = lua .. "(self:IsByte(" .. str:byte(i) .. "," .. i-1 .. ")" .. " or " .. "self:IsByte(" .. str:byte(i) .. "-32," .. i-1 .. ")) "
            else
                lua = lua .. "self:IsByte(" .. str:byte(i) .. "," .. i-1 .. ") "
            end

            if i ~= #str then
                lua = lua .. "and "
            end
        end

        lua = lua .. "then"
        lua = lua .. " self:Advance("..#str..") return true end"
        kernel = kernel .. lua .. "\n"
    end

    kernel = kernel .. "\nend"

    return assert(loadstring(kernel))()
end

function META:Error(msg, start, stop)
    if self.OnError then
        self:OnError(msg, start or self.i, stop or self.i)
    end
end

function META:NewToken(type, start, stop)
    local value = self:GetChars(start, stop)

    if type == "letter" and syntax.Keywords[value] then
        type = "keyword"
    end

    return Token(type, start, stop, value)
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
        return nil, "expected " .. print_util.QuoteToken(self:GetChars(start, self.i - 1) .. "[") .. " got " .. print_util.QuoteToken(self:GetChars(start, self.i))
    end

    self:Advance(1)

    local closing = "]" .. string.rep("=", (self.i - start) - 2) .. "]"
    local pos = self:FindNearest(closing)
    if pos then
        self:Advance(pos)
        return true
    end

    return nil, "expected "..print_util.QuoteToken(closing).." reached end of code"
end

do -- whitespace
    do
        function META:IsMultilineComment()
            return
                self:IsValue("-") and self:IsValue("-", 1) and self:IsValue("[", 2) and (
                    self:IsValue("[", 3) or self:IsValue("=", 3)
                )
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
        local function LINE_COMMENT(str, cmp, name, func_name)
            META["Is" .. func_name] = cmp

            META["Read" .. func_name] = function(self)
                self:Advance(#str)

                for _ = self.i, self:GetLength() do
                    if self:IsValue("\n") then
                        break
                    end
                    self:Advance(1)
                end

                return name
            end
        end

        LINE_COMMENT("--", function(self) return self:IsValue("-") and self:IsValue("-", 1) end, "line_comment", "LineComment")
    end

    do
        function META:IsSpace()
            return syntax.IsSpace(self:GetChar())
        end

        if ffi then
            local chars = "\32\t\n\r"
            local C = ffi.C
            local tonumber = tonumber

            function META:ReadSpace()
                self:Advance(tonumber(C.strspn(self.code_ptr + self.i - 1, chars)))
                return "space"
            end
        else
            function META:ReadSpace()
                for _ = self.i, self:GetLength() do
                    self:Advance(1)
                    if not syntax.IsSpace(self:GetChar()) then
                        break
                    end
                end

                return "space"
            end
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
            self:Advance(1)
            return "end_of_file"
        end
    end

    do
        function META:IsMultilineString()
            return self:IsValue("[") and (
                self:IsValue("[", 1) or self:IsValue("=", 1)
            )
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

        META.IsInNumberAnnotation = generate_lookup_function(syntax.NumberAnnotations, true)

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

            return self:IsInNumberAnnotation()
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
                if not syntax.IsNumber(self:GetChar()) then
                    self:Error("malformed " .. what .. " expected number, got " .. string.char(self:GetChar()), self.i - 2)
                    return false
                end
            end
            for _ = self.i, self:GetLength() do
                if not syntax.IsNumber(self:GetChar()) then
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
                elseif self:IsSymbol() or self:IsSpace() then
                    break
                elseif self:GetChar() ~= 0 then
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
                elseif self:IsSymbol() or self:IsSpace() then
                    break
                elseif self:GetChar() ~= 0 then
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

                if syntax.IsNumber(self:GetChar()) then
                    self:Advance(1)
                --elseif self:IsSymbol() or self:IsSpace() then
                    --break
                else--if self:GetChar() ~= 0 then
                    --self:Error("malformed number "..self:GetChar().." in hex notation")
                    break
                end
            end

            return "number"
        end

        function META:IsNumber()
            return syntax.IsNumber(self:GetChar()) or (self:IsValue(".") and syntax.IsNumber(self:GetChar(1)))
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
        if syntax.IsLetter(self:GetChar()) then
            return true
        end
    end

    if ffi then
        local C = ffi.C
        local tonumber = tonumber
        local chars = ""

        for i = 1, 255 do
            if syntax.IsDuringLetter(i) then
                chars = chars .. string.char(i)
            end
        end

        function META:ReadLetter()
            self:Advance(tonumber(C.strspn(self.code_ptr + self.i - 1, chars)))
            return "letter"
        end
    else
        function META:ReadLetter()
            for _ = self.i, self:GetLength() do
                self:Advance(1)
                if not syntax.IsDuringLetter(self:GetChar()) then
                    break
                end
            end

            return "letter"
        end
    end
end

do
    function META:IsSymbol()
        return syntax.IsSymbol(self:GetChar())
    end

    META.IsInSymbol = generate_lookup_function(syntax.SymbolCharacters)

    function META:ReadSymbol()
        if self:IsInSymbol() then
            return "symbol"
        end

        return nil
    end
end

do
    function META:IsShebang()
        return self.i == 1 and self:IsValue("#")
    end

    function META:ReadShebang()
        for _ = self.i, self:GetLength() do
            self:Advance(1)
            if self:IsValue("\n") then
                break
            end
        end
        return "shebang"
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

    local wbuffer

    for i = 1, self:GetLength() do
        local start = self.i
        local type = self:ReadWhiteSpace()
        if not type then
            break
        end
        wbuffer = wbuffer or {}
        wbuffer[i] = self:NewToken(type, start, self.i - 1)
    end

    local start = self.i
    local type = self:ReadNonWhiteSpace()

    local tk = self:NewToken(type or "unknown", start, self.i - 1)
    tk.whitespace = wbuffer
    return tk
end

function META:GetTokens()
    self:ResetState()

    local tokens = {}

    for i = self.i, self:GetLength() + 1 do
        local token = self:ReadToken()

        tokens[i] = token

        if token.type == "end_of_file" then
            token.value = ""
            break
        end
    end

    return tokens
end

return function(code)
    local self = setmetatable({}, META)
    self:OnInitialize(code)
    return self
end