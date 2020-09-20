local T = require("test.helpers")
local run = T.RunCode

test("pairs on literal table", function()
    run[[
        local tbl = {1,2,3}
        local key_sum = 0
        local val_sum = 0

        for key, val in pairs(tbl) do
            key_sum = key_sum + key
            val_sum = val_sum + val
        end
        
        type_assert(key_sum, 6)
        type_assert(val_sum, 6)
    ]]
end)

test("pairs on non literal table", function()
    run[[
        local tbl = {1,2,3} as {[number] = number}
        local key_sum = 0
        local val_sum = 0

        for key, val in pairs(tbl) do
            key_sum = key_sum + key
            val_sum = val_sum + val

            type_assert(key, _ as number)
            type_assert(val, _ as number)
        end
        
        type_assert(key_sum, _ as number | 0)
        type_assert(val_sum, _ as number | 0)
    ]]
end)


test("pairs on non literal table", function()
    run[[
        local tbl:{[number] = number} = {1,2,3}
        
        for key, val in pairs(tbl) do
            type_assert(key, _ as number)
            type_assert(val, _ as number)
        end
    ]]
end)

test("pairs on any should at least make k,v any", function()
    run[[
        local key, val

        for k,v in pairs(unknown) do
            key = k
            val = v
        end

        type_assert(key, _ as any | nil)
        type_assert(val, _ as any | nil)
    ]]
end)