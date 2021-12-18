local T = require("test.helpers")
local run = T.RunCode

run[[
    local lol
    do
        lol = 1
    end

    do
        types.assert(lol, 1)
    end
]]

run([[
    -- test shadow upvalues
    local foo = 1337

    local function test()
        types.assert(foo, 1337)
    end
    
    local foo = 666
]])

run([[
    -- test shadow upvalues
    local foo = 1337

    function test()
        types.assert(foo, 1337)
    end
    
    local foo = 666
]])

run[[
    local foo = 1337

    local function test()
        if math.random() > 0.5 then
            types.assert(foo, 1337)
        end
    end

    local foo = 666
]]

run[[
    local x = 0

    local function lol()
        types.assert(x, _ as 0 | 1 | 2)
    end
    
    local function foo()
        x = x + 1
    end
    
    local function bar()
        x = x + 1
    end
]]