local ffi = require("ffi")
local u32 = require("libraries.data_structures.primitives").u32
local malloc = ffi.C.malloc
local realloc = ffi.C.realloc

return function(T, growth_size)
    growth_size = growth_size or 32
    local ctype = ffi.typeof("struct { $ pos; $ len; $ * items; }", u32, u32, T)
    local size = ffi.sizeof(T)

    local META = {}
    META.__index = META

    local function check_bounds(i)
        if i < 0 then
            error("index " .. i .. " is out of bounds")
        end
    end

    function META:Push(val)
        check_bounds(self.pos)

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

        self.items[i] = val
    end

    function META:Get(i)
        check_bounds(i)
        return self.items[i]
    end

    function META:__len()
        return tonumber(self.pos)
    end

    function META:Grow()
        self.len = self.len + growth_size
        self.items = realloc(self.items, size * self.len)
        
        if self.items == nil then
            error("realloc failed")
        end
    end

    function META:__new(...)
        self = ffi.new(self)
        self.pos = 0
        self.len = 0
        self:Grow()
        return self
    end

    ffi.metatype(ctype, META)

    return ctype
end