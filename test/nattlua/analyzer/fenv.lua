local T = require("test.helpers")
local run = T.RunCode

run[[
    local func = function() 
        types.assert(foo, 1337)
    end

    setfenv(func, {
        foo = 1337
    })

    func()

    types.assert(getfenv(func).foo, 1337)
]]