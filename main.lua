package.path = package.path .. ";./src/?.lua"

if arg and arg[1] then
    local oh = require("oh")
    local f = io.open(arg[1], "r")
    local str = f:read("*all")
    f:close()
    return assert(oh.loadstring(str))(unpack(arg))
end