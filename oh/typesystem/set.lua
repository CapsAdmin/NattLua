local types = require("oh.typesystem.types")
local Set = {}
Set.Type = "set"
Set.__index = Set

local sort = function(a, b) return a < b end

function Set:PrefixOperator(op, val, env)
    local set = {}

    for _, v in ipairs(self.datai) do
        local val, err = v:PrefixOperator(op, val, env)
        if not val then
            return val, err
        end
        table.insert(set, val)
    end

    return Set:new(set)
end

function Set:GetSignature()
    local s = {}

    for _, v in ipairs(self.datai) do
        table.insert(s, types.GetSignature(v))
    end

    table.sort(s, sort)

    return table.concat(s, "|")
end

function Set:Call(arguments)
    local out = types.Set:new()

    for _, obj in ipairs(self.datai) do
        if not obj.Call then
            return false, "set contains uncallable object " .. tostring(obj)
        end

        local return_tuple = obj:Call(arguments)

        if return_tuple then
            out:AddElement(return_tuple)
        end
    end

    return types.Tuple:new({out})
end

function Set:__tostring()
    local s = {}
    for _, v in ipairs(self.datai) do
        table.insert(s, tostring(v))
    end

    table.sort(s, function(a, b) return a < b end)

    return table.concat(s, " | ")
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

function Set:Get(key, from_dictionary)
    key = types.Cast(key)

    if from_dictionary then
        for _, obj in ipairs(self.datai) do
            if obj.Get then
                local val = obj:Get(key)
                if val then
                    return val
                end
            end
        end
    end

    local val = self.data[key.type] or self.data[key:GetSignature()]
    if val then
        return val
    end

    for _, obj in ipairs(self.datai) do
        if obj.volatile then
            return obj
        end
    end
end

function Set:Set(key, val)
    self:AddElement(val)
    return true
end

function Set:SupersetOf(sub)
    if sub.Type == "tuple" and sub:GetLength() == 1 then
        sub = sub.data[1]
    end

    if sub.Type == "object" then
        return self:Get(sub) ~= nil
    end

    if sub.Type == "set" then
        for k,v in ipairs(sub.datai) do
            if self.data[types.GetSignature(v)] == nil or not v:SupersetOf(self.data[types.GetSignature(v)]) then
                return false
            end
        end
        return true
    elseif not self:Get(sub) then
        return false
    end

    for _, e in ipairs(self.datai) do
        if not sub:Get(e)then
            return false
        end
    end

    return true
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
        if not v.const then
            return false
        end
    end

    return true
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

for k,v in pairs(types.BaseObject) do Set[k] = v end
types.Set = Set

return Set