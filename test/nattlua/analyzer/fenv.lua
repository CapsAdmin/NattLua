local T = require("test.helpers")
local run = T.RunCode

run[[
    local func = function() 
        type_assert(foo, 1337)
    end

    setfenv(func, {
        foo = 1337
    })

    func()

    type_assert(getfenv(func).foo, 1337)
]]