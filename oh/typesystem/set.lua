local types = require("oh.typesystem.types")
local META = {}
META.Type = "set"
META.__index = META

local sort = function(a, b) return a < b end

function META:GetSignature()
    local s = {}

    for _, v in ipairs(self:GetTypes()) do
        table.insert(s, v:GetSignature())
    end

    table.sort(s, sort)

    return table.concat(s, "|")
end

function META:__tostring()
    local s = {}

    for _, v in ipairs(self:GetTypes()) do
        table.insert(s, tostring(v))
    end

    table.sort(s, function(a, b) return a < b end)

    return table.concat(s, " | ")
end


function META:AddType(e)
    if e.Type == "set" then
        for _, e in ipairs(e:GetTypes()) do
            self:AddType(e)
        end

        return self
    end

    local sig = e:GetSignature()

    if not self.data[sig] then
        self.data[sig] = e
        table.insert(self:GetTypes(), e)
    end

    return self
end

function META:GetTypes()
    return self.datai
end

function META:GetLength()
    return #self:GetTypes()
end

function META:RemoveType(e)
    self.data[e:GetSignature()] = nil
    for i,v in ipairs(self:GetTypes()) do
        if v:GetSignature() == e:GetSignature() then
            table.remove(self:GetTypes(), i)
            return
        end
    end
end

function META:Get(key, from_table)
    key = types.Cast(key)

    if from_table then
        for _, obj in ipairs(self:GetTypes()) do
            if obj.Get then
                local val = obj:Get(key)
                if val then
                    return val
                end
            end
        end
    end

    local errors = {}

    for _, obj in ipairs(self:GetTypes()) do
        local ok, reason = key:SubsetOf(obj)

        if ok then
            return obj
        end

        table.insert(errors, reason)
    end

    return types.errors.other(table.concat(errors, "\n"))
end

function META:Set(key, val)
    self:AddType(val)
    return true
end

function META:IsEmpty()
    return self:GetTypes()[1] == nil
end

function META:GetData()
    return self:GetTypes()
end


function META:IsTruthy()
    if self:IsEmpty() then return false end

    for _, obj in ipairs(self:GetTypes()) do
        if obj:IsTruthy() then
            return true
        end
    end
    return false
end

function META:IsFalsy()
    if self:IsEmpty() then return false end

    for _, obj in ipairs(self:GetTypes()) do
        if obj:IsFalsy() then
            return true
        end
    end
    return false
end

function META:GetTruthy()
    local copy = self:Copy()
    for _, obj in ipairs(self:GetTypes()) do
        if not obj:IsTruthy() then
            copy:RemoveType(obj)
        end
    end
    return copy
end

function META:GetFalsy()
    local copy = self:Copy()
    for _, obj in ipairs(self:GetTypes()) do
        if not obj:IsFalsy() then
            copy:RemoveType(obj)
        end
    end
    return copy
end

function META:IsType(typ)
    if self:IsEmpty() then return false end

    for _, obj in ipairs(self:GetTypes()) do
        if obj.Type ~= typ then
            return false
        end
    end
    return true
end

function META:HasType(typ)
    return self:GetType(typ) ~= false
end

function META:GetType(typ)
    for _, obj in ipairs(self:GetTypes()) do
        if obj.Type == typ then
            return obj
        end
    end
    return false
end

function META.SubsetOf(A, B)
    if B.Type == "tuple" then
        if B:GetLength() == 1 then
            B = B:Get(1)
        else
            return types.errors.other(tostring(A) .. " cannot contain tuple " .. tostring(B))
        end
    end

    if B.Type ~= "set" then
        return A:SubsetOf(types.Set({B}))
    end

    for _, a in ipairs(A:GetTypes()) do
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

    for _, e in ipairs(set:GetTypes()) do
        copy:AddType(e)
    end

    return copy
end


function META:Intersect(set)
    local copy = types.Set()

    for _, e in ipairs(self:GetTypes()) do
        if set:Get(e) then
            copy:AddType(e)
        end
    end

    return copy
end


function META:Subtract(set)
    local copy = self:Copy()

    for _, e in ipairs(self:GetTypes()) do
        copy:RemoveType(e)
    end

    return copy
end

function META:Copy()
    local copy = types.Set()
    for _, e in ipairs(self:GetTypes()) do
        copy:AddType(e)
    end
    copy.node = self.node
    copy.explicit_not_literal = self.explicit_not_literal
    return copy
end

function META:IsLiteral()
    if self.explicit_not_literal then
        return false, "explicitly not literal"
    end

    for _, v in ipairs(self:GetTypes()) do
        if not v:IsLiteral() then
            return false
        end
    end

    return true
end

function META:IsTruthy()
    for _, v in ipairs(self:GetTypes()) do
        if v:IsTruthy() then
            return true
        end
    end

    return false
end


function META:IsFalsy()
    for _, v in ipairs(self:GetTypes()) do
        if v:IsFalsy() then
            return true
        end
    end

    return false
end

function META:DisableTruthy()
    local found = {}
    for _, v in ipairs(self:GetTypes()) do
        if v:IsTruthy() then
            table.insert(found, v)
            self:RemoveType(v)
        end
    end
    self.truthy_disabled = found
end

function META:EnableTruthy()
    if not self.truthy_disabled then return end
    for _, v in ipairs(self.truthy_disabled) do
        self:AddType(v)
    end
end

function META:DisableFalsy()
    local found = {}
    for _, v in ipairs(self:GetTypes()) do
        if v:IsFalsy() then
            table.insert(found, v)
            self:RemoveType(v)
        end
    end
    self.falsy_disabled = found
end

function META:EnableFalsy()
    if not self.falsy_disabled then return end
    for _, v in ipairs(self.falsy_disabled) do
        self:AddType(v)
    end
end

function META:Initialize(data)
    self.data = {}
    self.datai = {}

    if data then
        for _, v in ipairs(data) do
            self:AddType(v)
        end
    end

    return true
end

function META:Max(val)
    local copy = self:Copy()
    for _, e in ipairs(copy:GetTypes()) do
        e:Max(val)
    end
    return copy
end

function META:Call(analyzer, arguments, ...)
    if self:IsEmpty() then
        return types.errors.other("cannot call empty set")
    end

    local set = self
    for _, obj in ipairs(self:GetData()) do
        if obj.Type ~= "function" and obj.Type ~= "table" and obj.Type ~= "any" then
            return types.errors.other("set "..tostring(set).." contains uncallable object " .. tostring(obj))
        end
    end

    local errors = {}

    for _, obj in ipairs(self:GetData()) do
        if obj.Type == "function" and arguments:GetLength() < obj:GetArguments():GetMinimumLength() then
            table.insert(errors, "invalid amount of arguments: " .. tostring(arguments) .. " ~= " .. tostring(obj:GetArguments()))
        else
            local res, reason = analyzer:Call(obj, arguments, ...)

            if res then
                return res
            end

            table.insert(errors, reason)
        end
    end

    return types.errors.other(table.concat(errors, "\n"))
end

return types.RegisterType(META)