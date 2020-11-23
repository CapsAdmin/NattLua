local ffi = require("ffi")
local DynamicArrayType = require("nattlua.other.data_structures.dynamic_array")

return function(T, growth_size)
    growth_size = growth_size or 4096

    local Pool = DynamicArrayType(T, growth_size)

    local i = -1
    local pool = Pool(growth_size)

    pool:Grow()

    return function()
        i = i + 1

        if i >= pool.len then
            pool:Grow()
        end

        return pool:Get(i)
    end
end