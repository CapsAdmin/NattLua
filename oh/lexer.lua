return function(lexer_meta, syntax)
    local helpers = require("oh.helpers")

    local ref = 0
    local meta = {}
    meta.__index = meta
    function meta:__tostring()
        return string.format("[token - %s][ %s ] %d", self.type, self.value, self.ref)
    end
    local function Token(type, start, stop, value)
        ref = ref + 1
        return setmetatable({
            ref = ref,
            type = type,
            start = start,
            stop = stop,
            value = value,
        }, meta)
    end

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

    function META.GenerateMap(str)
        local out = {}
        for i = 1, #str do
            out[str:byte(i)] = true
        end
        return out
    end

    function META.GenerateLookupFunction(tbl, lower)
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

        return assert(load(kernel))()
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
        elseif type == "symbol" then
            if syntax.PrefixOperators[value] then
                type = "operator_prefix"
            elseif syntax.PostfixOperators[value] then
                type = "operator_postfix"
            elseif syntax.BinaryOperators[value] then
                type = "operator_binary"
            end
        end

        return Token(type, start, stop, value)
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

    do
        function META:IsSymbol()
            return syntax.IsSymbol(self:GetChar())
        end

        META.IsInSymbol = META.GenerateLookupFunction(syntax.SymbolCharacters)

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

            if self.comment_escape and self:IsValue("]") and self:IsValue("]", 1) then
                self.comment_escape = false
                self:Advance(2)
            end

            local type = self:ReadWhiteSpace()
            if not type then
                break
            end
            wbuffer = wbuffer or {}
            wbuffer[i] = self:NewToken(type, start, self.i - 1)
        end

        local start = self.i
        local type = self:ReadNonWhiteSpace()

        if type == nil then
            type = "unknown"
            self:Advance(1)
        end

        local tk = self:NewToken(type, start, self.i - 1)
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

    for k, v in pairs(lexer_meta) do
        META[k] = v
    end

    return function(code)
        local self = setmetatable({}, META)
        self:OnInitialize(code)
        return self
    end
end