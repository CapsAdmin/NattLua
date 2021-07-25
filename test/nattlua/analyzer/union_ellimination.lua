local T = require("test.helpers")
local run = T.RunCode

run[[
    local function test() 
        if MAYBE then
            return nil
        end
        return 2
    end
    
    local x = { lol = _ as false | 1 }
    if not x.lol then
        x.lol = test()
        types.assert(x.lol, _ as 2 | nil)
    end

    types.assert(x.lol, _ as 1 | 2 | false | nil)
]]

run[[
    local x = _ as nil | 1 | false
    if x then x = false end
    types.assert<|x, nil | false|>

    local x = _ as nil | 1
    if not x then x = 1 end
    types.assert<|x, 1|>

    local x = _ as nil | 1
    if x then x = nil end
    types.assert<|x, nil|>
]]
