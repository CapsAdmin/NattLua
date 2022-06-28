local T = require("test.helpers")
local analyze = T.RunCode
analyze([[
    local type i = 0
    for k,v in ipairs(_ as any) do 
        attest.equal(k, _ as any)
        attest.equal(v, _ as any)
        attest.equal<|i, 0|>
    
        type i = i + 1
    end
    
    attest.equal<|i, 1|>
]])
analyze[[
    local tbl: {[number] = {
        foo = nil | {[number] = boolean}
    }}
    
    for k,v in ipairs(tbl) do
        if v.foo then
            attest.equal(v.foo,  _ as {[number] = boolean})
        end
    end
]]
analyze[[
    local function test(): number
        local foo = 1
        return 1
    end
    
    for _, token in ipairs({1}) do
        break
    end

    -- make sure break does not leak onto deferred analysis of test()
]]
analyze[[
    local sum = 0

    for i, num in ipairs({10, 20}) do
        sum = sum + i + num
    end
    
    attest.equal(sum, 33)
]]
analyze[[
    local sum = 0

    for i, num in ipairs({10, 20}) do
        sum = sum + i + num
        if math.random() > 0.5 then
            break
        end
    end

    attest.equal(sum, _ as number)
]]
analyze[[
    local e = {
        SOCK_SEQPACKET = 5,
        SOCK_DCCP = 6,
    }
    local what = "SOCK_"
    
    for k, v in pairs(e) do
        if k:sub(0, #what) == what then
            local lol = k:sub(#what + 1)    
            lol:lower()
        end
    end
]]