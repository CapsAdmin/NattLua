local types = require("oh.typesystem.types")
local syntax = require("oh.lua.syntax")
local bit = not _G.bit and require("bit32") or _G.bit

local META = {}
META.Type = "string"
META.__index = META

function META:GetLuaType()
    return self.Type
end

function META:GetSignature()
    local s = "string"

    if self.literal then
        s = s .. "-" .. self:GetData()
    end

    if self.pattern_contract then
        s = s .. "-" .. tostring(self.pattern_contract)
    end

    return s
end

function META:GetData()
    return self.data
end

function META:Copy()
    local copy =  types.String(self.data):MakeLiteral(self.literal)
    copy.node = self.node
    return copy
end

function META.SubsetOf(A, B)
    if B.Type == "tuple" and B:GetLength() == 1 then B = B:Get(1) end

    if B.Type == "set" then
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

    if B.Type == "string" then

        if B.pattern_contract then
            if not A:IsLiteral() then
                return types.errors.other("must be a literal")
            end

            if not A:GetData():find(B.pattern_contract) then
                return types.errors.other("the pattern failed to match")
            end

            return true
        end


        if A.literal == true and B.literal == true then
            -- compare against literals
            if A.data == B.data then
                return true
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
        return types.errors.other(tostring(A) .. " is not the same type as " .. tostring(B))
    end
    error("this shouldn't be reached ")

    return false
end

function META:__tostring()
    if self.literal then
        if self.data then
            return ("%q"):format(self.data)
        end

        if self.data == nil then
            return "string"
        end

        return tostring(self.data) .. (self.max and (".." .. tostring(self.max.data)) or "")
    end

    if self.data == nil then
        return "string"
    end

    return "string" .. "(".. tostring(self.data) .. (self.max and (".." .. self.max.data) or "") .. ")"
end

function META:IsFalsy()
    return false
end

function META:IsTruthy()
    return true
end

function META:Initialize()
    self.meta = require("oh.lua.string_meta")

    return self
end

return types.RegisterType(META)