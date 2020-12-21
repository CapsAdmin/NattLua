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

pending("pairs on non literal table", function()
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


pending("pairs on non literal table", function()
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

run[[
    local x = 0
    for i = 1, 10 do
        x = x + i
    end
    type_assert(x, 55)
]]

run[[
    local x = 0
    for i = 1, 10 do
        x = x + i
        if i == 4 then
            break
        end
    end
    type_assert(x, 10)
]]

run[[
    local x = 0
    for i = 1, 10 do
        x = x + i
        if i == maybe then
            break
        end
    end
    type_assert(x, _ as number)
]]

run[[
    local a, b = 0, 0
    for i = 1, 5000 do
        if 5 == i then
            a = 1
        end
        if i == 5 then
            b = 1
        end
    end
    type_assert(a, _ as 1 | 0)
    type_assert(b, _ as 1 | 0)
]]

run[[
    local t = {foo = true}
    for k,v in pairs(t) do
        type_assert(k, _ as "foo")
        type_assert(v, _ as true)
    end
]]

pending[[
    local tbl: {
        foo = nil | string,
        bar = nil | number,
    }

    for k, v in pairs(tbl) do
        type_assert(k, _ as "foo" | "bar")
        type_assert(v, _ as number | string)
    end
]]