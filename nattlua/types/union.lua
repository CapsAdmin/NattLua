local types = require("nattlua.types.types")
local META = {}
META.Type = "union"
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
    if e.Type == "union" then
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
            break
        end
    end
    return self
end


function META:Clear()
    self.datai = {}
    self.data = {}
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
        local ok, reason = key:IsSubsetOf(obj)

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

function META:HasNil()
    for _, obj in ipairs(self:GetTypes()) do
        if obj.Type == "symbol" and obj.data == nil then
            return true
        end
    end
    return false
end

function META:GetType(typ)
    for _, obj in ipairs(self:GetTypes()) do
        if obj.Type == typ then
            return obj
        end
    end
    return false
end

function META.IsSubsetOf(A, B)
    if B.Type == "tuple" then
        if B:GetLength() == 1 then
            B = B:Get(1)
        else
            return types.errors.other(tostring(A) .. " cannot contain tuple " .. tostring(B))
        end
    end

    if B.Type ~= "union" then
        return A:IsSubsetOf(types.Union({B}))
    end

    for _, a in ipairs(A:GetTypes()) do
        local b, reason = B:Get(a)

        if not b then
            return types.errors.missing(B, a)
        end

        local ok, reason = a:IsSubsetOf(b)

        if not ok then
            return types.errors.subset(a, b, reason)
        end
    end

    return true
end

function META:Union(union)
    local copy = self:Copy()

    for _, e in ipairs(union:GetTypes()) do
        copy:AddType(e)
    end

    return copy
end


function META:Intersect(union)
    local copy = types.Union()

    for _, e in ipairs(self:GetTypes()) do
        if union:Get(e) then
            copy:AddType(e)
        end
    end

    return copy
end


function META:Subtract(union)
    local copy = self:Copy()

    for _, e in ipairs(self:GetTypes()) do
        copy:RemoveType(e)
    end

    return copy
end

function META:Copy()
    local copy = types.Union()
    for _, e in ipairs(self:GetTypes()) do
        copy:AddType(e)
    end
    copy:CopyInternalsFrom(self)
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
        return types.errors.other("cannot call empty union")
    end

    local union = self
    for _, obj in ipairs(self:GetData()) do
        if obj.Type ~= "function" and obj.Type ~= "table" and obj.Type ~= "any" then
            return types.errors.other("union "..tostring(union).." contains uncallable object " .. tostring(obj))
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

function META:MakeCallableUnion(analyzer, node)
    local new_union = types.Union()
    local truthy_union = types.Union()
    local falsy_union = types.Union()

    for _, v in ipairs(self:GetData()) do               
        if v.Type ~= "function" and v.Type ~= "table" and v.Type ~= "any" then
            falsy_union:AddType(v)
            analyzer:ErrorAndCloneCurrentScope(node, "union "..tostring(self).." contains uncallable object " .. tostring(v), self)
        else
            truthy_union:AddType(v)
            new_union:AddType(v)
        end
    end

    truthy_union.upvalue = self.upvalue
    falsy_union.upvalue = self.upvalue
    new_union.truthy_union = truthy_union
    new_union.falsy_union = falsy_union

    return truthy_union:SetSource(node, new_union, self)
end

return types.RegisterType(META)