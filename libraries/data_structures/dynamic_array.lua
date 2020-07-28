local ffi = require("ffi")
local u32 = require("libraries.data_structures.primitives").u32
local Struct = require("libraries.data_structures.struct")

return function(T)
    local ctype = ffi.typeof("struct { $ pos; $ len; $ * items; }", u32, u32, T)
    local size = ffi.sizeof(T)

    local META = {}
    META.__index = META

    local function check_bounds(self, i)
        if i < 0 then
            error("index " .. i .. " is out of bounds")
        end
    end

    function META:Push(val)
        check_bounds(self, self.pos)

        while self.pos >= self.len do
            self:Grow()
        end

        self.items[self.pos] = val
        self.pos = self.pos + 1
    end

    function META:Set(i, val)

        if i > 0 then
            while i >= self.len do
                self:Grow()
            end
        end

        check_bounds(self, i)

        self.items[i] = val
    end

    function META:Get(i)
        check_bounds(self, i)
        return self.items[i]
    end

    function META:__len()
        return tonumber(self.pos)
    end

    function META:Grow()
        self.len = self.len + 32

        if self.items == nil then
            self.items = ffi.C.malloc(size * self.len)
        else
            self.items = ffi.C.realloc(self.items, size * self.len)
        end

        if self.items == nil then
            error("realloc failed")
        end
    end

    function META:new()
        local self = ctype()
        self.pos = 0
        self.len = 0
        self:Grow()
        return self
    end

    ffi.metatype(ctype, META)

    return ctype
end