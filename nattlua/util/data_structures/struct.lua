local ffi = require("ffi")

local function check(cdef, ...)
    local tbl = {...}
    local i = 1
    print((cdef:gsub("%$", function()
        local val = tostring(tbl[i])
        i = i + 1
        return val
    end)))

    return cdef, ...
end

return function(tbl, tag)
    local members = {}
    local ctypes = {}
    local offset = 0

    for i, val in ipairs(tbl) do
        local key = assert(val[1], "first value must be a string")
        local t = assert(val[2], "second value must be a ctype or string")
        local member = string.format("$ %s;", key)

        if type(t) == "string" then
            if t:find("self") then
                t = t:gsub("self", "struct " .. tag)
                member = string.format("%s %s;", t, key)
                t = nil
            else
                t = ffi.typeof(t)
            end
        end

        members[i] = member

        if t then
            table.insert(ctypes, t)
        end
    end

    if tag then
        table.insert(ctypes, 1, tag)
        ffi.cdef(check("struct $ {" .. table.concat(members, "") .. "};", unpack(ctypes)))
        return ffi.typeof("struct " .. tag)
    end

    return ffi.typeof("struct{" .. table.concat(members, "") .. "}", unpack(ctypes))
end