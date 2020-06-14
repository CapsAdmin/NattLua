local types = require("oh.typesystem.types")
types.Initialize()

local Object = function(...) return types.Object:new(...) end

local function cast(...)
    local ret = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        local t = type(v)
        if t == "number" or t == "string" or t == "boolean" then
            ret[i] = Object(t, v, true)
        else
            ret[i] = v
        end
    end

    return ret
end

return {
    Set = function(...) return types.Set:new(cast(...)) end,
    Tuple = function(...) return types.Tuple:new({...}) end,
    Number = function(n) return Object("number", n, true) end,
    String = function(n) return Object("string", n, true) end,
    Object = Object,
    Dictionary = function(data) return types.Dictionary:new(data or {}) end
}