local oh = {}

function oh.attributes(obj, ...)
    for _, data in ipairs({...}) do
        local name = data[1]
        if name == "meta" then
            setmetatable(obj, data[2])
        end
    end
    return obj
end

function oh.struct(tbl)
    local types = {}
    local str = {""}
    for i, line in ipairs(tbl) do
        local name, cdata = line[1], line[2]
        if type(cdata) ~= "cdata" then
            error("unexpected type " .. type(cdata) .. " to field " .. name)
        end
        str[i] = "$ "..name..";"
        types[i] = cdata
    end
    return require("ffi").typeof("struct{" .. table.concat(str) .. "}", unpack(types))
end

function oh.number_postfix(num, what)
    if what == "k" then
        return num * 1000
    end

    if what == "b" then
        return num
    elseif what == "kb" then
        return num*1024*1
    elseif what == "mb" then
        return num*(1024^2)
    elseif what == "gb" then
        return num*(1024^3)
    elseif what == "pb" then
        return num*(1024^4)
    end
    return num
end

local ffi = require("ffi")
_G.u32 = ffi.typeof("uint32_t")

_G.sizeof = ffi.sizeof

return oh