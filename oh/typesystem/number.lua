local types = require("oh.typesystem.types")
local syntax = require("oh.lua.syntax")
local bit = not _G.bit and require("bit32") or _G.bit

local META = {}
META.Type = "number"
META.__index = META

function META:GetSignature()

    if self.literal then
        return "number-" .. types.GetSignature(self.data)
    end

    return "number"
end

function META:Get(key)
    return false, "cannot " .. tostring(self) .. "[" .. tostring(key) .."]"
    --return self.data
end

function META:Set(key, val)
    return false, "cannot " .. tostring(self) .. "[" .. tostring(key) .."] = " .. tostring(val)
    --self.data = val
end

function META:GetData()
    return self.data
end

function META:Copy()
    local data = self.data

    local copy = types.Number(data):MakeLiteral(self.literal)

    copy.volatile = self.volatile

    return copy
end

function META.SubsetOf(A, B)
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

function META:__tostring()
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
        return tostring(self.data) .. (self.max and (".." .. tostring(self.max)) or "")
    end

    if self.data == nil then
        return "number"
    end

    return "number" .. "(".. tostring(self.data) .. (self.max and (".." .. tostring(self.max)) or "") .. ")"
end

function META:Serialize()
    return self:__tostring()
end

function META:Max(val)
    if val.Type == "set" then
        local max = {}
        for _, obj in ipairs(val:GetElements()) do
            if obj.Type ~= "number" then
                return false, "the set contains non numbers"
            end
            if obj:IsLiteral() then
                table.insert(max, obj)
            else
                self.literal = false
                self.data = nil
                return self
            end
        end
        table.sort(max, function(a, b) return a.data > b.data end)
        val = max[1]
    end

    if val.Type ~= "number" then
        return false, "max must be a number"
    end

    if not val:IsLiteral() then
        self.literal = false
        self.data = nil
        return self
    end


    self.max = val
    return self
end

function META:IsVolatile()
    return self.volatile == true
end

function META:IsFalsy()
    return false
end

function META:IsTruthy()
    return true
end

return types.RegisterType(META)