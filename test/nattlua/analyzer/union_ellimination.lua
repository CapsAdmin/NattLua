local T = require("test.helpers")
local run = T.RunCode

pending[[
    local function test() 
        if MAYBE then
            return nil
        end
        return 2
    end
    
    local x = { lol = _ as false | 1 }
    if not x.lol then
        x.lol = test()
        type_assert(x.lol, _ as 2 | nil)
    end
    type_assert(x.lol, _ as 1 | 2 | nil)
]]

pending[[
    local x = _ as nil | 1 | false
    if x then x = false end
    type_assert<|x, nil | false|>

    local x = _ as nil | 1
    if not x then x = 1 end
    type_assert<|x, 1|>

    local x = _ as nil | 1
    if x then x = nil end
    type_assert<|x, nil|>
]]
