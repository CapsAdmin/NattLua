local types = require("nattlua.types.types")

local META = {}
META.Type = "symbol"
META.__index = META

function META:GetLuaType()
    return type(self.data)
end

function META:GetSignature()
    return "symbol" .. "-" .. tostring(self.data)
end

function META:__tostring()
    return tostring(self.data)
end

function META:GetData()
    return self.data
end

function META:Copy()
    local copy = types.Symbol(self:GetData())
    copy.truthy = self.truthy
    copy:CopyInternalsFrom(self)

    return copy
end

function META.IsSubsetOf(A, B)
    if B.Type == "tuple" and B:GetLength() == 1 then B = B:Get(1) end

    if B.Type == "union" then
        local errors = {}
        for _, b in ipairs(B:GetTypes()) do
            local ok, reason = A:IsSubsetOf(b)
            if ok then
                return true
            end
            table.insert(errors, reason)
        end
        return types.errors.subset(A, b, table.concat(errors, "\n"))
    end

    if A.Type == "any" then return true end
    if B.Type == "any" then return true end

    if A.Type ~= B.Type then
        return types.errors.type_mismatch(A, B)
    end

    if A:GetData() ~= B:GetData() then
        return types.errors.value_mismatch(A, B)
    end

    return true
end

function META:IsFalsy()
    return not self.truthy
end

function META:IsTruthy()
   return self.truthy
end

function META:Initialize(data)
    self.literal = true
    self.truthy = not not data

    return true
end

return types.RegisterType(META)