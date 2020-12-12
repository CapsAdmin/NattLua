local T = require("test.helpers")
local run = T.RunCode

run[[
    local { WorldToLocal, Vector, Angle } = loadfile("nattlua/runtime/glua.nlua")()
    local pos, ang = WorldToLocal(Vector(1,2,3), Angle(1,5,2), Vector(5,6,2), Angle(10235,123,123))
    
    type_assert(pos, _ as Vector)
    type_assert(ang, _ as Angle)
]]

run[[
    local { hook } = loadfile("nattlua/runtime/glua.nlua")()
    
    hook.Add("OnStart", "mytest", function(a,b,c, d)
        type_assert(a, _ as string)
        type_assert(b, _ as boolean)        
    end)
    
    hook.Add("OnStop", "mytest", function(a,b,c, d)
        type_assert(a, _ as string)
        type_assert(b, _ as string)
        return 1
    end)
]]