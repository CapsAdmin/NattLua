local T = require("test.helpers")
local run = T.RunCode
run[[
    local co = coroutine.create(function(a,b,c)
        attest.equal(a, 1)
        attest.equal(b, 2)
        attest.equal(c, 3)
    end)

    coroutine.resume(co,1,2,3)
]]
run[[
    local func = coroutine.wrap(function(a)
        attest.equal(a, 1)
    end)
    
    func(1)
]]
