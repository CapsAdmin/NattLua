local T = require("test.helpers")
local run = T.RunCode

run[[
    local co = coroutine.create(function(a,b,c)
        type_assert(a, 1)
        type_assert(b, 2)
        type_assert(c, 3)
    end)

    coroutine.resume(co,1,2,3)
]]

run[[
    local func = coroutine.wrap(function(a)
        type_assert(a, 1)
    end)
    
    func(1)
]]