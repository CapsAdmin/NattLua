local types = require("nattlua.types.types")

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
    return true
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

function META:Call()
    return types.Tuple({}):AddRemainder(types.Tuple({types.Any()}):SetRepeat(math.huge))
end

return types.RegisterType(META)