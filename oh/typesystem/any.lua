local types = require("oh.typesystem.types")

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

function META:Serialize()
    return self:__tostring()
end

function META:IsVolatile()
    return self.volatile == true
end

function META:IsFalsy()
    return true
end

function META:IsTruthy()
    return true
end

return types.RegisterType(META)