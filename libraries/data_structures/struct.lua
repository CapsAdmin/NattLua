local ffi = require("ffi")

return function(tbl)
    local members = {}
    local ctypes = {}

    for i, val in ipairs(tbl) do
        local key = assert(val[1], "first value must be a string")
        local t = assert(val[2], "second value must be a ctype or string")

        if type(t) == "string" then
            t = ffi.typeof(t)
        end

        members[i] = string.format("$ %s;", key)
        ctypes[i] = t
    end

    return ffi.typeof("struct{" .. table.concat(members, "") .. "}", unpack(ctypes))
end