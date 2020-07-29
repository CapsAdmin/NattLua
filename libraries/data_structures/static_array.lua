
local ffi = require("ffi")

return function(T, length)
    local ctype = ffi.typeof("struct { $ items[$]; }", T, length)

    local META = {}
    META.__index = META

    local function check_bounds(i)
        if i < 0 or i >= length then
            error("index " .. i .. " is out of bounds", 3)
        end
    end

    function META:Set(i, val)
        check_bounds(i)

        self.items[i] = val
    end

    function META:Get(i)
        check_bounds(i)

        return self.items[i]
    end

    function META:__len()
        return tonumber(length)
    end

    function META:new()
        return ctype()
    end

    ffi.metatype(ctype, META)

    return ctype
end