local types = require("nattlua.types.types")
local syntax = require("nattlua.syntax.syntax")
local bit = not _G.bit and require("bit32") or _G.bit

local META = {}
META.Type = "number"
META.__index = META

function META:GetLuaType()
    return self.Type
end

function META:GetSignature()
    local s = "N"

    if self.literal then
        s = s .. "-" .. tostring(self:GetData())
    end

    if self.max then
        s = s .. "-" .. self.max:GetSignature()
    end

    return s
end

function META:GetData()
    return self.data
end

function META:Copy()
    local copy = types.Number(self.data):MakeLiteral(self.literal)
    if self.max then
        copy.max = self.max:Copy()
    end
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
        return types.errors.subset(A, b, errors)
    end

    if A.Type == "any" then return true end
    if B.Type == "any" then return true end

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
        return types.errors.type_mismatch(A, B)
    end

    error("this shouldn't be reached")

    return false
end

function META:__tostring()
    --return "「"..self.uid .. " 〉" .. self:GetSignature() .. "」"

    if self.literal then
        return tostring(self.data) .. (self.max and (".." .. tostring(self.max)) or "")
    end

    if self.data == nil then
        return "number"
    end

    return "number" .. "(".. tostring(self.data) .. (self.max and (".." .. tostring(self.max)) or "") .. ")"
end


function META:Max(val)
    if val.Type == "union" then
        local max = {}
        for _, obj in ipairs(val:GetTypes()) do
            if obj.Type ~= "number" then
                return types.errors.other({"unable to set the max value of ", self, " because ", val, " contains non numbers"})
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
        return types.errors.other("max must be a number, got " .. tostring(val))
    end

    if not val:IsLiteral() then
        self.literal = false
        self.data = nil
        
        return self
    end

    self.max = val
    
    return self
end

function META:IsFalsy()
    return false
end

function META:IsTruthy()
    return true
end

return types.RegisterType(META)