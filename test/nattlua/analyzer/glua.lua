local T = require("test.helpers")
local run = T.RunCode

run[[
    local { WorldToLocal, Vector, Angle } = loadfile("nattlua/runtime/gmod.nlua")()
    local pos, ang = WorldToLocal(Vector(1,2,3), Angle(1,5,2), Vector(5,6,2), Angle(10235,123,123))
    
    type_assert(pos, _ as Vector)
    type_assert(ang, _ as Angle)
]]

run[[
    type hook = {}

    local type Events = {
        OnStart = (function(string, boolean): nil),
        OnStop = (function(string, string, string): number)
    }
    
    type function hook.Add(eventName: string, obj: any, callback: (function(...): ...))    
        -- swap the argument and return tuple type
        local cb = env.typesystem.Events[eventName]
        
        callback:SetReturnTypes(cb:GetType():GetReturnTypes())
        callback:SetArguments(cb:GetType():GetArguments())
    
        -- call the function
        analyzer:Assert(analyzer.current_statement, analyzer:Call(callback, callback:GetArguments(), analyzer.current_expression))
    end
    
    hook.Add("OnStart", "mytest", function(a,b,c, d)
        print(a,b,c, d)
    end)
    
    hook.Add("OnStop", "mytest", function(a,b,c, d)
        print(a,b,c, d)
        
        return 1
    end)
]]