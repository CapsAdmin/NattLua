local types = require("oh.typesystem.types")

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
    copy.node = self.node

    return copy
end

function META.SubsetOf(A, B)
    if B.Type == "tuple" and B:GetLength() == 1 then B = B:Get(1) end

    if B.Type == "union" then
        local errors = {}
        for _, b in ipairs(B:GetTypes()) do
            local ok, reason = A:SubsetOf(b)
            if ok then
                return true
            end
            table.insert(errors, reason)
        end
        return types.errors.other(table.concat(errors, "\n"))
    end

    if A.Type == "any" then return true end
    if B.Type == "any" then return true end

    if A.Type ~= B.Type or A.data ~= B.data then
        return types.errors.other(tostring(A) .. " is not the same as " .. tostring(B))
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