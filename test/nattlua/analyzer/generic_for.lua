local T = require("test.helpers")
local run = T.RunCode
local transpile = T.Transpile

run([[
    local type i = 0
    for k,v in ipairs(_ as any) do 
        type_assert(k, _ as any)
        type_assert(v, _ as any)
        type_assert<|i, 0|>
    
        type i = i + 1
    end
    
    type_assert<|i, 1|>
]])

run[[
    local tbl: {[number] = {
        foo = nil | {[number] = boolean}
    }}
    
    for k,v in ipairs(tbl) do
        if v.foo then
            type_assert(v.foo,  _ as {[number] = boolean})
        end
    end
]]

run[[
    local function test(): number
        local foo = 1
        return 1
    end
    
    for _, token in ipairs({1}) do
        break
    end

    -- make sure break does not leak onto deferred analysis of test()
]]

run[[
    local sum = 0

    for i, num in ipairs({10, 20}) do
        sum = sum + i + num
    end
    
    type_assert(sum, 33)
]]

run[[
    local sum = 0

    for i, num in ipairs({10, 20}) do
        sum = sum + i + num
        if math.random() > 0.5 then
            break
        end
    end

    type_assert(sum, _ as number)
]]