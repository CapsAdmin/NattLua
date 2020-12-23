local types = require("nattlua.types.types")

local META = {}
META.Type = "error"
META.__index = META

function META:GetSignature()
    return "error"
end

function META:Copy()
    return self
end

function META.IsSubsetOf(A, B)
    return true
end

function META:__tostring()
    return "ERROR(" .. tostring(self:GetData()) .. ")"
end

function META:IsFalsy()
    return true
end

function META:IsTruthy()
    return false
end

function META:Initialize(msg)
    self:SetData(msg)
    return self
end

return types.RegisterType(META)