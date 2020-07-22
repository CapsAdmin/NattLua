local table_new = require("table.new")

local function pool(alloc, size)
    size = size or 3105585

    local records = 0
    for k,v in pairs(alloc()) do
        records = records + 1
    end

    local i
    local pool = table_new(size, records)

    local function refill()
        i = 1

        for i = 1, size do
            pool[i] = alloc()
        end
    end

    refill()

    return function()
        local tbl = pool[i]

        if not tbl then
            refill()
            tbl = pool[i]
        end

        i = i + 1

        return tbl
    end
end

local function list()
    local tbl
    local i

    local self = {
        clear = function(self)
            tbl = {}
            i = 1
        end,
        add = function(self, val)
            tbl[i] = val
            i = i + 1
        end,
        get = function(self)
            return tbl
        end
    }

    self:clear()

    return self
end

return function(lexer_meta, syntax)
    local helpers = require("oh.helpers")

    local function Token(type, start, stop, value)
        return {
            ref = ref,
            type = type,
            start = start,
            stop = stop,
            value = value,
        }
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
    end

    function META:ResetState()
        self.i = 1
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

    function META:SetPosition(i)
        self.i = i
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

    function META.BuildReadFunction(tbl, lower)
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
                local second_arg = "," .. i-1
                if i == 1 then
                    second_arg = ""
                end

                if lower then
                    lua = lua .. "(self:IsByte(" .. str:byte(i) .. second_arg .. ")" .. " or " .. "self:IsByte(" .. str:byte(i) .. "-32," .. i-1 .. ")) "
                else
                    lua = lua .. "self:IsByte(" .. str:byte(i) .. second_arg .. ") "
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

    do
        local get = pool(function() return {
            type = "something",
            value = "something",
            whitespace = false,
            start = 0,
            stop = 0,
        } end)

        function META:NewToken(type, start, stop, is_whitespace)
            local tk = get()

            tk.type = type
            tk.whitespace = is_whitespace
            tk.start = start
            tk.stop = stop

            return tk
        end
    end

    if ffi then
        local string_span = ffi.C.strspn
        local tonumber = tonumber

        local chars = ""
        for i = 1, 255 do
            if syntax.IsDuringLetter(i) then
                chars = chars .. string.char(i)
            end
        end

        function META:ReadLetter()
            if syntax.IsLetter(self:GetChar()) then
                self:Advance(tonumber(string_span(self.code_ptr + self.i - 1, chars)))
                return true
            end

            return false
        end
    else
        function META:ReadLetter()
            if syntax.IsLetter(self:GetChar()) then
                for _ = self.i, self:GetLength() do
                    self:Advance(1)
                    if not syntax.IsDuringLetter(self:GetChar()) then
                        break
                    end
                end
                return true
            end

            return false
        end
    end

    do
        if ffi then
            local tonumber = tonumber
            local string_span = ffi.C.strspn

            local chars = ""
            for i = 1, 255 do
                if syntax.IsSpace(i) then
                    chars = chars .. string.char(i)
                end
            end

            function META:ReadSpace()
                if syntax.IsSpace(self:GetChar()) then
                    self:Advance(tonumber(string_span(self.code_ptr + self.i - 1, chars)))
                    return true
                end

                return false
            end
        else
            function META:ReadSpace()
                if syntax.IsSpace(self:GetChar()) then
                    for _ = self.i, self:GetLength() do
                        self:Advance(1)
                        if not syntax.IsSpace(self:GetChar()) then
                            break
                        end
                    end
                    return true
                end

                return false
            end
        end
    end

    META.ReadSymbol = META.BuildReadFunction(syntax.SymbolCharacters)

    function META:ReadShebang()
        if self.i == 1 and self:IsValue("#") then
            for _ = self.i, self:GetLength() do
                self:Advance(1)
                if self:IsValue("\n") then
                    break
                end
            end
            return true
        end
        return false
    end

    function META:ReadEndOfFile()
        if self.i > self:GetLength()then
            -- nothing to capture, but remaining whitespace will be added
            self:Advance(1)
            return true
        end

        return false
    end

    function META:ReadUnknown()
        self:Advance(1)
        return "unknown", false
    end

    function META:ReadToken()
        if not self.NoShebang and self:ReadShebang() then
            return self:NewToken("shebang", 1, self.i - 1, false)
        end

        if self.comment_escape and self:IsValue("]") and self:IsValue("]", 1) then
            self.comment_escape = false
            self:Advance(2)
        end

        local start = self.i
        local type, whitespace = self:Read()

        local tk = self:NewToken(type, start, self.i - 1, whitespace)

        if self.potential_lua54_division_operator then
            tk.potential_lua54_division_operator = true
            self.potential_lua54_division_operator = false
        end

        return tk
    end

    function META:GetTokens()
        self:ResetState()

        local tokens = {}

        for i = self.i, self:GetLength() + 1 do
            tokens[i] = self:ReadToken()

            if tokens[i].type == "end_of_file" then
                break
            end
        end

        for _, token in ipairs(tokens) do
            token.value = self:GetChars(token.start, token.stop)
        end

        local buffer = list()
        local non_whitespace = list()

        local potential_whitespace = false

        for _, token in ipairs(tokens) do
            if token.whitespace then
                token.whitespace = false

                if token.potential_lua54_division_operator then
                    potential_whitespace = true
                end


                buffer:add(token)
            else
                token.whitespace = buffer:get()

                if potential_whitespace then
                    token.potential_lua54_division_operator = true
                    potential_whitespace = false
                end

                non_whitespace:add(token)

                buffer:clear()
            end
        end

        tokens = non_whitespace:get()

        tokens[#tokens].value = ""

        return tokens
    end

    for k, v in pairs(lexer_meta) do
        META[k] = v
    end

    return function(code)
        local self = setmetatable({}, META)
        self.potential_lua54_division_operator = false
        self.comment_escape = false
        self.NoShebang = false
        self:OnInitialize(code)
        return self
    end
end