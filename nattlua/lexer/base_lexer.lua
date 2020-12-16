local list = require("nattlua.other.list")

return function(META--[[#: {
    syntax = {
        IsDuringLetter = (function(number): boolean),        
        IsLetter = (function(number): boolean),
        IsSpace = (function(number): boolean),
        GetSymbols = (function(): {[number] = string}),
        [string] = any,
    },
    [string] = any,
}]])

    --[[#
        type META.code = string
        type META.i = number
        type META.code_ptr = {
            [number] = number,
            __meta = self,
            __add = (function(self, number): self),
            __sub = (function(self, number): self)
        }
    ]]

    local ok, table_new = pcall(require, "table.new")
    if not ok then
        table_new = function() return {} end
    end
    local ffi = jit and require("ffi")

    local function pool(alloc --[[#: (function(): {[string] = any})]], size --[[#: nil | number]])
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

    local function list2()
        local tbl --[[#: {[number] = any}]]
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
                return list.fromtable(tbl)
            end
        }

        self:clear()

        return self
    end

    local function remove_bom_header(str --[[#: string]])
        if str:sub(1, 2) == "\xFE\xFF" then
            return str:sub(3)
        elseif str:sub(1, 3) == "\xEF\xBB\xBF" then
            return str:sub(4)
        end
        return str
    end

    local function Token(type --[[#: string]], start --[[#: number]], stop --[[#: number]], value --[[#: string]])
        return {
            type = type,
            start = start,
            stop = stop,
            value = value,
        }
    end

    local B = string.byte

    if ffi then
        ffi.cdef([[
            size_t strspn( const char * str1, const char * str2 );
        ]])
    end

    function META:GetLength()
        return #self.code
    end

    if ffi then
        local ffi_string = ffi.string

        function META:GetChars(start --[[#: number]], stop --[[#: number]])
            return ffi_string(self.code_ptr + start - 1, (stop - start) + 1)
        end

        function META:GetChar(offset --[[#: number]])
                return self.code_ptr[self.i + offset - 1]
            end

        function META:GetCurrentChar()
            return self.code_ptr[self.i - 1]
        end
    else
        function META:GetChars(start --[[#: number]], stop --[[#: number]])
            return self.code:sub(start, stop)
        end

        function META:GetChar(offset --[[#: number]])
            return self.code:byte(self.i + offset)
            end

        function META:GetCurrentChar()
            return self.code:byte(self.i)
        end
    end

    function META:ResetState()
        self.i = 1
    end

    function META:FindNearest(str --[[#: string]])
        local _, stop = self.code:find(str, self.i, true)

        if stop then
            return stop - self.i + 1
        end

        return false
    end

    function META:ReadChar()
        local char = self:GetCurrentChar()
        self.i = self.i + 1
        return char
    end

    function META:Advance(len --[[#: number]])
        self.i = self.i + len
    end

    function META:SetPosition(i --[[#: number]])
        self.i = i
    end

    function META:IsValue(what--[[#:string]], offset--[[#:number]])
        return self:IsByte(B(what), offset)
    end

    function META:IsCurrentValue(what--[[#:string]])
        return self:IsCurrentByte(B(what))
    end

    function META:IsCurrentByte(what--[[#:string]])
        return self:GetCurrentChar() == what
    end

    function META:IsByte(what--[[#:string]], offset--[[#:number]])
            return self:GetChar(offset) == what
        end

    function META.GenerateMap(str--[[#:string]])
        local out = {}
        for i = 1, #str do
            out[str:byte(i)] = true
        end
        return out
    end

    function META.BuildReadFunction(tbl--[[#:{[number] = string}]], lower--[[#: boolean]])
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
                    lua = lua .. "(self:IsByte(" .. str:byte(i) .. second_arg .. ", 0)" .. " or " .. "self:IsByte(" .. str:byte(i) .. "-32," .. i-1 .. ")) "
                else
                    lua = lua .. "self:IsByte(" .. str:byte(i) .. second_arg .. ", 0) "
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

    function META:Error(msg--[[#:string]], start--[[#:number]], stop--[[#:number]])
        if self.OnError then
            self:OnError(self.code, self.name, msg, start or self.i, stop or self.i)
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

        function META:NewToken(type--[[#:string]], start--[[#:number]], stop--[[#:number]], is_whitespace--[[#:boolean]])
            local tk = get()

            tk.type = type
            tk.whitespace = is_whitespace
            tk.start = start
            tk.stop = stop

            return tk
        end
    end

    if ffi then
        local string_span = ffi.C.strspn --[[# as function(any, any): number]]
        local tonumber = tonumber

        local chars = ""
        for i = 1, 255 do
            if META.syntax.IsDuringLetter(i) then
                chars = chars .. string.char(i)
            end
        end

        function META:ReadLetter()
            if META.syntax.IsLetter(self:GetCurrentChar()) then
                self:Advance(tonumber(string_span(self.code_ptr + self.i - 1, chars)))
                return true
            end

            return false
        end
    else
        function META:ReadLetter()
            if META.syntax.IsLetter(self:GetCurrentChar()) then
                for _ = self.i, self:GetLength() do
                    self:Advance(1)
                    if not META.syntax.IsDuringLetter(self:GetCurrentChar()) then
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
            local string_span = ffi.C.strspn --[[# as function(any, any): number]]

            local chars = ""
            for i = 1, 255 do
                if META.syntax.IsSpace(i) then
                    chars = chars .. string.char(i)
                end
            end

            function META:ReadSpace()
                if META.syntax.IsSpace(self:GetCurrentChar()) then
                    self:Advance(tonumber(string_span(self.code_ptr + self.i - 1, chars)))
                    return true
                end

                return false
            end
        else
            function META:ReadSpace()
                if META.syntax.IsSpace(self:GetCurrentChar()) then
                    for _ = self.i, self:GetLength() do
                        self:Advance(1)
                        if not META.syntax.IsSpace(self:GetCurrentChar()) then
                            break
                        end
                    end
                    return true
                end

                return false
            end
        end
    end

    META.ReadSymbol = META.BuildReadFunction(META.syntax.GetSymbols())

    function META:ReadShebang()
        if self.i == 1 and self:IsCurrentValue("#") then
            for _ = self.i, self:GetLength() do
                self:Advance(1)
                if self:IsCurrentValue("\n") then
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

    function META:ReadSimple()
        local start = self.i
        local type, is_whitespace = self:Read()
        return type, is_whitespace, start, self.i - 1
    end

    function META:ReadToken()
        if self:ReadShebang() then
            return self:NewToken("shebang", 1, self.i - 1, false)
        end
        
        local type, is_whitespace, start, stop = self:ReadSimple()

        local tk = self:NewToken(type, start, stop, is_whitespace)

        self:OnTokenRead(tk)

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

        local whitespace_buffer = {}
        local whitespace_buffer_i = 1

        local non_whitespace = {}
        local non_whitespace_i = 1


        for _, token in ipairs(tokens) do
            if token.type ~= "discard" then
                if token.whitespace then
                    token.whitespace = false

                    whitespace_buffer[whitespace_buffer_i] = token
                    whitespace_buffer_i = whitespace_buffer_i + 1

                else
                    token.whitespace = list.fromtable(whitespace_buffer)

                    non_whitespace[non_whitespace_i] = token
                    non_whitespace_i = non_whitespace_i + 1

                    whitespace_buffer = {}
                    whitespace_buffer_i = 1
                end
            end
        end

        local tokens = list.fromtable(non_whitespace)

        tokens[#tokens].value = ""

        return tokens
    end

    function META:OnInitialize()

    end

    function META:OnTokenRead(tk)
        
    end

    function META:Initialize(code --[[#: string]])
        self.code = remove_bom_header(code)

        if ffi then
            self.code_ptr_ref = self.code
            self.code_ptr = ffi.cast("const uint8_t *", self.code_ptr_ref)
        end

        self:ResetState()

        self:OnInitialize()
    end
end