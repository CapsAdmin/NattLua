local T = require("test.helpers")
local run = T.RunCode
local transpile = T.Transpile

run([[
    local type i = 0
    for k,v in ipairs(_ as any) do 
        types.assert(k, _ as any)
        types.assert(v, _ as any)
        types.assert<|i, 0|>
    
        type i = i + 1
    end
    
    types.assert<|i, 1|>
]])

run[[
    local tbl: {[number] = {
        foo = nil | {[number] = boolean}
    }}
    
    for k,v in ipairs(tbl) do
        if v.foo then
            types.assert(v.foo,  _ as {[number] = boolean})
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
    
    types.assert(sum, 33)
]]

run[[
    local sum = 0

    for i, num in ipairs({10, 20}) do
        sum = sum + i + num
        if math.random() > 0.5 then
            break
        end
    end

    types.assert(sum, _ as number)
]]