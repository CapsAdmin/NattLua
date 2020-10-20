local types = require("nattlua.typesystem.types")

local META = {}
META.Type = "never"
META.__index = META

function META:GetSignature()
    return "never"
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
    return "never"
end

function META:IsFalsy()
    return true
end

function META:IsTruthy()
    return false
end

return types.RegisterType(META)