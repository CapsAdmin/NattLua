local types = require("nattlua.types.types")
local syntax = require("nattlua.syntax.syntax")
local bit = not _G.bit and require("bit32") or _G.bit
local type_errors = require("nattlua.types.error_messages")

local META = {}
META.Type = "string"
META.__index = META

function META:GetLuaType()
    return self.Type
end

function META:GetSignature()
    local s = "S"

    if self:IsLiteral() then
        s = s .. "-" .. self:GetData()
    end

    if self.pattern_contract then
        s = s .. "-" .. self.pattern_contract
    end

    return s
end

function META:Copy()
    local copy =  types.String(self:GetData()):SetLiteral(self:IsLiteral())
    copy.pattern_contract = self.pattern_contract
    copy:CopyInternalsFrom(self)
    return copy
end

function META:SetPattern(str)
    self.pattern_contract = str
end

function META.IsSubsetOf(A, B)
    if B.Type == "tuple" and B:GetLength() == 1 then B = B:Get(1) end
    
    if B.Type == "union" then
        local errors = {}
        for _, b in ipairs(B:GetData()) do
            local ok, reason = A:IsSubsetOf(b)
            if ok then
                return true
            end
            table.insert(errors, reason)
        end
        return type_errors.other(errors)
    end

    if B.Type == "any" then return true end

    if B.Type ~= "string" then
        return type_errors.type_mismatch(A, B)
    end

    if 
        (A:IsLiteral() and B:IsLiteral() and A:GetData() == B:GetData()) or -- "A" subsetof "B"
        (A:IsLiteral() and not B:IsLiteral()) or -- "A" subsetof string
        (not A:IsLiteral() and not B:IsLiteral()) -- string subsetof string
    then
        return true
    end

    if B.pattern_contract then
        if not A:IsLiteral() then
            return type_errors.literal(A, "must be a literal when comparing against string pattern")
        end

        if not A:GetData():find(B.pattern_contract) then
            return type_errors.string_pattern(A, B)
        end

        return true
    end

    if A:IsLiteral() and B:IsLiteral() then
        return type_errors.value_mismatch(A, B)
    end

    return type_errors.subset(A, B)
end

function META:__tostring()

    if self.pattern_contract then
        return "$(" .. self.pattern_contract .. ")"
    end

    if self:IsLiteral() then
        if self:GetData() then
            return "\"" .. self:GetData() .. "\""
        end

        if self:GetData() == nil then
            return "string"
        end

        return tostring(self:GetData()) .. (self.max and (".." .. tostring(self.max:GetData())) or "")
    end

    if self:GetData() == nil then
        return "string"
    end

    return "string" .. "(".. tostring(self:GetData()) .. (self.max and (".." .. self.max:GetData()) or "") .. ")"
end

function META:IsFalsy()
    return false
end

function META:IsTruthy()
    return true
end

function META:Initialize()
    self:SetMetaTable(require("nattlua.runtime.string_meta"))

    return self
end

return types.RegisterType(META)