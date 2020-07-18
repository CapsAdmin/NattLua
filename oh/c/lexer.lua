local syntax = require("oh.c.syntax")
local helpers = require("oh.helpers")

local META = {}

META.NoShebang = true

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
        return nil, "expected " .. helpers.QuoteToken(self:GetChars(start, self.i - 1) .. "[") .. " got " .. helpers.QuoteToken(self:GetChars(start, self.i))
    end

    self:Advance(1)

    local closing = "]" .. string.rep("=", (self.i - start) - 2) .. "]"
    local pos = self:FindNearest(closing)
    if pos then
        self:Advance(pos)
        return true
    end

    return nil, "expected "..helpers.QuoteToken(closing).." reached end of code"
end

function META:ConsumeMultilineComment()
    if not (self:IsValue("/") and self:IsValue("*", 1)) then return false end

    self:Advance(2)

    while not (self:IsValue("*") and self:IsValue("/")) do
        self:Advance(1)
    end

    return true
end

function META:ConsumeLineComment()
    if not (self:IsValue("/") and self:IsValue("/", 1)) then return false end

    self:Advance(2)

    for _ = self.i, self:GetLength() do
        if self:IsValue("\n") then
            break
        end
        self:Advance(1)
    end

    return true
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
            self:Error("expected multiline string to end: " .. err, start, start + 1)
            return
        end

        return "string"
    end
end

do
    function META.GenerateMap(str)
        local out = {}
        for i = 1, #str do
            out[str:byte(i)] = true
        end
        return out
    end

    function META.BuildReadFunction(tbl)
        local copy = {}
        local done = {}

        for _, str in pairs(tbl) do
            if not done[str] then
                table.insert(copy, str)
                done[str] = true
            end
        end

        table.sort(copy, function(a, b) return #a > #b end)

        local kernel = "return function(self)\n"

        for _, str in pairs(copy) do
            local lua = _ == 1  and "if " or "elseif "

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
            lua = lua .. " self:Advance("..#str..") return true\n"
            kernel = kernel .. lua .. "\n"
        end

        kernel = kernel .. "end\n"
        kernel = kernel .. "\n"
        kernel = kernel .. "end\n"

        return assert(load(kernel))()
    end

    local allowed_hex = META.GenerateMap("1234567890abcdefABCDEF")

    META.ConsumeNumberAnnotation = META.BuildReadFunction(syntax.NumberAnnotations)

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

        return self:ConsumeNumberAnnotation()
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

do
    local B = string.byte

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
                        self:Error("expected " .. name:lower() .. " quote to end", start, self.i - 1)
                        return false
                    end

                    if char == B(quote) then
                        return "string"
                    end
                end
            end

            self:Error("expected " .. name:lower() .. " quote to end: reached end of file", start, self.i - 1)

            return false
        end
    end
end

function META:ConsumeMacro()
    if not self:IsValue("#") then return end
    self:Advance(1)

    while true do
        if self:IsValue("\n") and not self:IsValue("\\", -1) then
            break
        end
        self:Advance(1)
    end

    return "macro"
end

function META:ReadWhiteSpace()
    if
    self:IsSpace() then                 return self:ReadSpace() elseif
    self:ConsumeMultilineComment() then return "multiline_comment" elseif
    self:ConsumeLineComment() then      return "line_comment" elseif
    false then end
end

function META:ReadNonWhiteSpace()
    if
    self:ConsumeMacro() then            return "macro" elseif
    self:IsMultilineString() then       return self:ReadMultilineString() elseif
    self:IsNumber() then                return self:ReadNumber() elseif
    self:IsSingleString() then          return self:ReadSingleString() elseif
    self:IsDoubleString() then          return self:ReadDoubleString() elseif

    self:IsEndOfFile() then             return self:ReadEndOfFile() elseif
    self:IsLetter() then                return self:ReadLetter() elseif
    self:IsSymbol() then                return self:ReadSymbol() elseif
    false then end
end

return require("oh.lexer")(META, require("oh.c.syntax"))