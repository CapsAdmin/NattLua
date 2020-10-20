local types = require("nattlua.typesystem.types")

local META = {}
META.Type = "error"
META.__index = META

function META:GetSignature()
    return "error"
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
    return "ERROR(" .. tostring(self.data) .. ")"
end

function META:IsFalsy()
    return true
end

function META:IsTruthy()
    return false
end

function META:Initialize(msg)
    self.data = msg
    return self
end

return types.RegisterType(META)