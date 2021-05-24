local T = require("test.helpers")
local run = T.RunCode

run([[
    -- test shadow upvalues
    local foo = 1337

    local function test()
        type_assert(foo, 1337)
    end
    
    local foo = 666
]])

run([[
    -- test shadow upvalues
    local foo = 1337

    function test()
        type_assert(foo, 1337)
    end
    
    local foo = 666
]])
