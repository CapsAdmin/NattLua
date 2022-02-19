local T = require("test.helpers")
local run = T.RunCode
local transpile = T.Transpile
run([[
    local type i = 0
    for k,v in ipairs(_ as any) do 
        attest.equal(k, _ as any)
        attest.equal(v, _ as any)
        attest.equal<|i, 0|>
    
        type i = i + 1
    end
    
    attest.equal<|i, 1|>
]])
run[[
    local tbl: {[number] = {
        foo = nil | {[number] = boolean}
    }}
    
    for k,v in ipairs(tbl) do
        if v.foo then
            attest.equal(v.foo,  _ as {[number] = boolean})
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
    
    attest.equal(sum, 33)
]]
run[[
    local sum = 0

    for i, num in ipairs({10, 20}) do
        sum = sum + i + num
        if math.random() > 0.5 then
            break
        end
    end

    attest.equal(sum, _ as number)
]]
