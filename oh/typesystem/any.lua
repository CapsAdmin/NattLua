local types = require("oh.typesystem.types")
local analyzer_env = require("oh.lua.analyzer_env")

local META = {}
META.Type = "any"
META.__index = META

function META:GetSignature()
    return "any"
end

function META:Get(key)
    return self
end

function META:Set(key, val)

end

function META:GetData()
    return self.data
end

function META:Copy()
    return self
end

function META.SubsetOf(A, B)
    return true
end

function META:__tostring()
    return "any"
end

function META:IsFalsy()
    return true
end

function META:IsTruthy()
    return true
end

function META:Initialize()
    --[[
    local a = analyzer_env.GetCurrentAnalyzer()
    if a then
        if a.path and a.path:find("base_typesystem") then
            return self
        end
        if a.current_expression then
            a:Error(a.current_expression, "implicit any")
        end
    end
]]
    return self
end

return types.RegisterType(META)