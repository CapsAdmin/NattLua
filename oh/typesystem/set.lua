local types = require("oh.typesystem.types")
local META = {}
META.Type = "set"
META.__index = META

local sort = function(a, b) return a < b end

function META:GetSignature()
    local s = {}

    for _, v in ipairs(self.datai) do
        table.insert(s, types.GetSignature(v))
    end

    table.sort(s, sort)

    return table.concat(s, "|")
end

function META:__tostring()
    local s = {}

    for _, v in ipairs(self.datai) do
        table.insert(s, tostring(v))
    end

    table.sort(s, function(a, b) return a < b end)

    return "⦃" .. table.concat(s, ", ") .. "⦄"
end

function META:Serialize()
    return self:__tostring()
end

function META:AddElement(e)
    if e.Type == "set" then
        for _, e in ipairs(e.datai) do
            self:AddElement(e)
        end

        return self
    end

    if not self.data[types.GetSignature(e)] then
        self.data[types.GetSignature(e)] = e
        table.insert(self.datai, e)
    end

    return self
end

function META:GetLength()
    return #self.datai
end

function META:GetElements()
    return self.datai
end

function META:RemoveElement(e)
    self.data[types.GetSignature(e)] = nil
    for i,v in ipairs(self.datai) do
        if types.GetSignature(v) == types.GetSignature(e) then
            table.remove(self.datai, i)
            return
        end
    end
end

function META:Get(key, from_table)
    key = types.Cast(key)

    if from_table then
        for _, obj in ipairs(self.datai) do
            if obj.Get then
                local val = obj:Get(key)
                if val then
                    return val
                end
            end
        end
    end

    local errors = {}

    for _, obj in ipairs(self.datai) do
        if obj.volatile then
            return obj
        end

        local ok, reason = key:SubsetOf(obj)

        if ok then
            return obj
        end

        table.insert(errors, reason)
    end

    return false, table.concat(errors, "\n")
end

function META:Set(key, val)
    self:AddElement(val)
    return true
end

function META:IsEmpty()
    return self.datai[1] == nil
end

function META:GetData()
    return self.datai
end


function META:IsTruthy()
    if self:IsEmpty() then return false end

    for _, obj in ipairs(self:GetElements()) do
        if obj:IsTruthy() then
            return true
        end
    end
    return false
end

function META:IsFalsy()
    if self:IsEmpty() then return false end

    for _, obj in ipairs(self:GetElements()) do
        if obj:IsFalsy() then
            return true
        end
    end
    return false
end

function META:IsType(typ)
    if self:IsEmpty() then return false end

    for _, obj in ipairs(self:GetElements()) do
        if obj.Type ~= typ then
            return false
        end
    end
    return true
end

function META:HasType(typ)
    for _, obj in ipairs(self:GetElements()) do
        if obj.Type == typ then
            return true
        end
    end
    return false
end

function META:IsVolatile()
    for _, obj in ipairs(self:GetElements()) do
        if obj.volatile then
            return true
        end
    end

    return false
end

function META.SubsetOf(A, B)
    if B.Type == "tuple" then
        if B:GetLength() == 1 then
            B = B:Get(1)
        else
            return false, tostring(A) .. " cannot contain tuple " .. tostring(B)
        end
    end

    if B.Type ~= "set" then
        return A:SubsetOf(types.Set({B}))
    end

    if A:IsVolatile() then
        return true
    end

    for _, a in ipairs(A:GetElements()) do
        local b, reason = B:Get(a)

        if not b then
            return types.errors.missing(B, a)
        end

        local ok, reason = a:SubsetOf(b)

        if not ok then
            return types.errors.subset(a, b, reason)
        end
    end

    return true
end

function META:Union(set)
    local copy = self:Copy()

    for _, e in ipairs(set.datai) do
        copy:AddElement(e)
    end

    return copy
end


function META:Intersect(set)
    local copy = types.Set()

    for _, e in ipairs(self.datai) do
        if set:Get(e) then
            copy:AddElement(e)
        end
    end

    return copy
end


function META:Subtract(set)
    local copy = self:Copy()

    for _, e in ipairs(self.datai) do
        copy:RemoveElement(e)
    end

    return copy
end

function META:Copy()
    local copy = types.Set()
    for _, e in ipairs(self.datai) do
        copy:AddElement(e)
    end
    return copy
end

function META:IsLiteral()
    for _, v in ipairs(self.datai) do
        if not v:IsLiteral() then
            return false
        end
    end

    return true
end

function META:IsTruthy()
    for _, v in ipairs(self.datai) do
        if v:IsTruthy() then
            return true
        end
    end

    return false
end


function META:IsFalsy()
    for _, v in ipairs(self.datai) do
        if v:IsFalsy() then
            return true
        end
    end

    return false
end

function META:Initialize(data)
    self.data = {}
    self.datai = {}

    if data then
        for _, v in ipairs(data) do
            self:AddElement(v)
        end
    end
end

return types.RegisterType(META)