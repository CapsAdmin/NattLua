local T = require("test.helpers")
local run = T.RunCode

run[[
    local co = coroutine.create(function(a,b,c)
        types.assert(a, 1)
        types.assert(b, 2)
        types.assert(c, 3)
    end)

    coroutine.resume(co,1,2,3)
]]

run[[
    local func = coroutine.wrap(function(a)
        types.assert(a, 1)
    end)
    
    func(1)
]]