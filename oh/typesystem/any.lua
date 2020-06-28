local types = require("oh.typesystem.types")

local Any = {}
Any.Type = "any"
Any.__index = Any

function Any:GetSignature()
    return "any"
end

function Any:Get(key)
    return self
end

function Any:Set(key, val)

end

function Any:GetData()
    return self.data
end

function Any:Copy()
    return self
end

function Any.SubsetOf(A, B)
    return true
end

function Any:__tostring()
    return "any"
end

function Any:Serialize()
    return self:__tostring()
end

function Any:IsVolatile()
    return self.volatile == true
end

function Any:IsFalsy()
    return true
end

function Any:IsTruthy()
    return true
end

function Any:RemoveNonTruthy()
    return self
end

local uid = 0

function Any:new()
    local self = setmetatable({}, self)

    uid = uid + 1
    self.uid = uid

    self.Type = "any"
    assert(self.Type == "any")

    return self
end

types.RegisterType(Any)

return Any