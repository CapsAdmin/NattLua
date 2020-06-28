local types = require("oh.typesystem.types")
local syntax = require("oh.lua.syntax")
local bit = not _G.bit and require("bit32") or _G.bit

local Symbol = {}
Symbol.Type = "symbol"
Symbol.__index = Symbol

function Symbol:GetSignature()
    return "symbol" .. "-" .. tostring(self.data)
end

function Symbol:Get(key)
    return false, "cannot " .. tostring(self) .. "[" .. tostring(key) .."]"
    --return self.data
end

function Symbol:Set(key, val)
    return false, "cannot " .. tostring(self) .. "[" .. tostring(key) .."] = " .. tostring(val)
    --self.data = val
end

function Symbol:GetData()
    return self.data
end

function Symbol:Copy()
    local copy = Symbol:new(self:GetData())
    copy.truthy = self.truthy

    return copy
end

function Symbol.SubsetOf(A, B)
    if B.Type == "tuple" and B:GetLength() == 1 then B = B:Get(1) end

    if B.Type == "set" then
        local errors = {}
        for _, b in ipairs(B:GetElements()) do
            local ok, reason = A:SubsetOf(b)
            if ok then
                return true
            end
            table.insert(errors, reason)
        end
        return false, table.concat(errors, "\n")
    end

    if A.Type == "any" or A.volatile then return true end
    if B.Type == "any" or B.volatile then return true end


    if A.data ~= B.data then
        return false, tostring(A) .. " is not the same as " .. tostring(B)
    end

    return true
end

function Symbol:__tostring()
    return tostring(self.data)
end

function Symbol:Serialize()
    return self:__tostring()
end

function Symbol:IsVolatile()
    return self.volatile == true
end

function Symbol:IsFalsy()
    return not self.truthy
end

function Symbol:IsTruthy()
   return self.truthy
end

function Symbol:RemoveNonTruthy()
    return self
end

local uid = 0

function Symbol:new(data, truthy)
    local self = setmetatable({}, self)

    uid = uid + 1

    self.uid = uid
    self.data = data
    self.literal = true

    if truthy == nil then
        self.truthy = not not self.data
    else
        self.truthy = truthy
    end

    return self
end

types.RegisterType(Symbol)

return Symbol