local types = require("oh.typesystem.types")
local syntax = require("oh.lua.syntax")
local bit = not _G.bit and require("bit32") or _G.bit

local Number = {}
Number.Type = "number"
Number.__index = Number

function Number:GetSignature()

    if self.literal then
        return "number-" .. types.GetSignature(self.data)
    end

    return "number"
end

function Number:Get(key)
    return false, "cannot " .. tostring(self) .. "[" .. tostring(key) .."]"
    --return self.data
end

function Number:Set(key, val)
    return false, "cannot " .. tostring(self) .. "[" .. tostring(key) .."] = " .. tostring(val)
    --self.data = val
end

function Number:GetData()
    return self.data
end

function Number:Copy()
    local data = self.data

    local copy = Number:new(data, self.literal)

    copy.volatile = self.volatile

    return copy
end

function Number.SubsetOf(A, B)
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

    if B.Type == "number" then
        if A.literal == true and B.literal == true then
            -- compare against literals

            -- nan
            if A.Type == "number" and B.Type == "number" then
                if A.data ~= A.data and B.data ~= B.data then
                    return true
                end
            end

            if A.data == B.data then
                return true
            end

            if B.max then
                if A.data >= B.data and A.data <= B.max.data then
                    return true
                end
            end

            return types.errors.subset(A, B)
        elseif A.data == nil and B.data == nil then
            -- number contains number
            return true
        elseif A.literal and not B.literal then
            -- 42 subset of number?
            return true
        elseif not A.literal and B.literal then
            -- number subset of 42 ?
            return types.errors.subset(A, B)
        end

        -- number == number
        return true
    else
        return false, tostring(A) .. " is not the same type as " .. tostring(B)
    end
    error("this shouldn't be reached ")


    return false
end

function Number:__tostring()
    --return "「"..self.uid .. " 〉" .. self:GetSignature() .. "」"


    if self.volatile then
        local str = "number"

        if self.data ~= nil then
            str = str .. "(" .. tostring(self.data) .. ")"
        end

        str = str .. "💥"

        return str
    end

    if self.literal then
        if self.data == nil then
            return "number"
        end

        return tostring(self.data) .. (self.max and (".." .. tostring(self.max.data)) or "")
    end

    if self.data == nil then
        return "number"
    end

    return "number" .. "(".. tostring(self.data) .. (self.max and (".." .. self.max.data) or "") .. ")"
end

function Number:Serialize()
    return self:__tostring()
end

function Number:Max(val)
    if "number" == "number" then
        self.max = val
    end
    return self
end

function Number:IsVolatile()
    return self.volatile == true
end

function Number:IsFalsy()
    return false
end

function Number:IsTruthy()
    return true
end

function Number:RemoveNonTruthy()
    return self
end

local uid = 0

function Number:new(data, const)
    local self = setmetatable({}, self)

    uid = uid + 1

    self.uid = uid
    self.data = data
    self.literal = const

    return self
end

types.RegisterType(Number)

return Number