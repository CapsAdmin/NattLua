local T = require("test.helpers")
local run = T.RunCode

run[[
    local { WorldToLocal, Vector, Angle } = loadfile("nattlua/runtime/gmod.nlua")()
    local pos, ang = WorldToLocal(Vector(1,2,3), Angle(1,5,2), Vector(5,6,2), Angle(10235,123,123))
    
    type_assert(pos, _ as TVector)
    type_assert(ang, _ as TAngle)
]]

