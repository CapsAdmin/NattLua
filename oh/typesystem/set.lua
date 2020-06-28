local types = require("oh.typesystem.types")
local Set = {}
Set.Type = "set"
Set.__index = Set

local sort = function(a, b) return a < b end

function Set:GetSignature()
    local s = {}

    for _, v in ipairs(self.datai) do
        table.insert(s, types.GetSignature(v))
    end

    table.sort(s, sort)

    return table.concat(s, "|")
end

function Set:__tostring()
    local s = {}

    for _, v in ipairs(self.datai) do
        table.insert(s, tostring(v))
    end

    table.sort(s, function(a, b) return a < b end)

    return "⦃" .. table.concat(s, ", ") .. "⦄"
end

function Set:Serialize()
    return self:__tostring()
end

function Set:AddElement(e)
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

function Set:GetLength()
    return #self.datai
end

function Set:GetElements()
    return self.datai
end

function Set:RemoveElement(e)
    self.data[types.GetSignature(e)] = nil
    for i,v in ipairs(self.datai) do
        if types.GetSignature(v) == types.GetSignature(e) then
            table.remove(self.datai, i)
            return
        end
    end
end

function Set:Get(key, from_table)
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

    for _, obj in ipairs(self.datai) do
        if obj.volatile or key:SubsetOf(obj) then
            return obj
        end
    end
end

function Set:Set(key, val)
    self:AddElement(val)
    return true
end

function Set:IsEmpty()
    return self.datai[1] == nil
end

function Set:GetData()
    return self.datai
end

function Set:IsVolatile()
    for _, obj in ipairs(self:GetElements()) do
        if obj.volatile then
            return true
        end
    end

    return false
end

function Set.SubsetOf(A, B)
    if B.Type == "tuple" then
        if B:GetLength() == 1 then
            B = B:Get(1)
        else
            return false, tostring(A) .. " cannot contain tuple " .. tostring(B)
        end
    end

    if B.Type == "object" or B.Type == "table" then
        return A:SubsetOf(Set:new({B}))
    elseif B.Type == "set" then
        if A:IsVolatile() then
            return true
        end

        for _, a in ipairs(A:GetElements()) do
            local b = B:Get(a)

            if not b then
                return types.errors.missing(B, a)
            end

            if not a:SubsetOf(b) then
                return types.errors.subset(a, b)
            end
        end

        return true
    end

    error("unhandled type" .. tostring(B))
end

function Set:Union(set)
    local copy = self:Copy()

    for _, e in ipairs(set.datai) do
        copy:AddElement(e)
    end

    return copy
end


function Set:Intersect(set)
    local copy = types.Set:new()

    for _, e in ipairs(self.datai) do
        if set:Get(e) then
            copy:AddElement(e)
        end
    end

    return copy
end


function Set:Subtract(set)
    local copy = self:Copy()

    for _, e in ipairs(self.datai) do
        copy:RemoveElement(e)
    end

    return copy
end

function Set:Copy()
    local copy = Set:new()
    for _, e in ipairs(self.datai) do
        copy:AddElement(e)
    end
    return copy
end

function Set:IsConst()
    for _, v in ipairs(self.datai) do
        if not v:IsConst() then
            return false
        end
    end

    return true
end

function Set:IsType(str)
    for _, v in ipairs(self.datai) do
        if v.IsType and v:IsType(str) then
            return true
        end
    end

    return false
end

function Set:IsTruthy()
    for _, v in ipairs(self.datai) do
        if v:IsTruthy() then
            return true
        end
    end

    return false
end


function Set:IsFalsy()
    for _, v in ipairs(self.datai) do
        if v:IsFalsy() then
            return true
        end
    end

    return false
end

function Set:new(values)
    local self = setmetatable({}, Set)

    self.data = {}
    self.datai = {}

    if values then
        for _, v in ipairs(values) do
            self:AddElement(v)
        end
    end

    return self
end

types.RegisterType(Set)

return Set