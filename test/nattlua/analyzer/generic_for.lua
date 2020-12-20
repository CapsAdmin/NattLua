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