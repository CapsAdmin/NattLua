local T = require("test.helpers")
local run = T.RunCode

run[[
    import_type("nattlua/definitions/glua.nlua")    
    types.assert(string.Split("1|2|3", "|"), {"1","2","3"})
]]

run[[
    local { WorldToLocal, Vector, Angle } = import_type("nattlua/definitions/glua.nlua")
    local pos, ang = WorldToLocal(Vector(1,2,3), Angle(1,5,2), Vector(5,6,2), Angle(10235,123,123))
    
    types.assert(pos, _ as Vector)
    types.assert(ang, _ as Angle)
]]

run[[
    local { hook } = import_type("nattlua/definitions/glua.nlua")
    
    hook.Add("OnStart", "mytest", function(a,b,c, d)
        types.assert(a, _ as string)
        types.assert(b, _ as boolean)        
    end)
    
    hook.Add("OnStop", "mytest", function(a,b,c, d)
        types.assert(a, _ as string)
        types.assert(b, _ as string)
        return 1
    end)
]]