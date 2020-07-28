local ffi = require("ffi")
local u32 = require("libraries.data_structures.primitives").u32

return function(T)
    local element_size = ffi.sizeof(T)

    local ctype = ffi.typeof("struct { $ len; $ * items;}", u32, T)

    local META = {}
    META.__index = META

    local function check_bounds(self, i)
        if i < 0 or i >= self.len then
            error("index " .. i .. " is out of bounds", 3)
        end
    end

    function META:Set(i, val)
        check_bounds(self, i)

        self.items[i] = val
    end

    function META:Get(i)
        check_bounds(self, i)

        return self.items[i]
    end

    function META:__len()
        return tonumber(self.len)
    end

    function META:SliceView(start, stop)
        local arr = ctype()
        arr.len = (stop - start) + 1
        arr.items = self.items + start
        return arr
    end

    function META:Slice(start, stop)
        local arr = ctype()
        arr.len = (stop - start) + 1
        arr.items = ffi.C.malloc(element_size * arr.len)
        ffi.copy(arr.items, self.items + start, element_size * arr.len)
        return arr
    end

    function META:new(length)
        return ctype(length, ffi.C.malloc(element_size * length))
    end

    ffi.metatype(ctype, META)

    return ctype
end