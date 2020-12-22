local types = require("nattlua.types.types")
local syntax = require("nattlua.syntax.syntax")
local bit = not _G.bit and require("bit32") or _G.bit

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

function META:GetData()
    return self.data
end

function META:Copy()
    local copy =  types.String(self.data):MakeLiteral(self.literal)
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
        for _, b in ipairs(B:GetTypes()) do
            local ok, reason = A:IsSubsetOf(b)
            if ok then
                return true
            end
            table.insert(errors, reason)
        end
        return types.errors.other(table.concat(errors, "\n"))
    end

    if B.Type == "any" then return true end

    if B.Type ~= "string" then
        return types.errors.type_mismatch(A, B)
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
            return types.errors.literal(A, "must be a literal when comparing against string pattern")
        end

        if not A:GetData():find(B.pattern_contract) then
            return types.errors.string_pattern(A, B)
        end

        return true
    end

    if A:IsLiteral() and B:IsLiteral() then
        return types.errors.value_mismatch(A, B)
    end

    return types.errors.subset(A, B)
end

function META:__tostring()

    if self.pattern_contract then
        return "$(" .. self.pattern_contract .. ")"
    end

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
    self:SetMetaTable(require("nattlua.runtime.string_meta"))

    return self
end

return types.RegisterType(META)