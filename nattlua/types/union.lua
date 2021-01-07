local types = require("nattlua.types.types")
local type_errors = require("nattlua.types.error_messages")

local META = {}
META.Type = "union"
require("nattlua.types.base")(META)

local sort = function(a, b) return a:GetSignature() < b:GetSignature() end

function META:Sort()
    self.sort_me = true
end

function META.Equal(a,b)
    if a.suppress then return true end
    if a.Type ~= b.Type then return false end
    if #a.data ~= #b.data then return false end

    a.suppress = true
    for i = 1, #a.data do
        local ok = false
        local a = a.data[i]
        for i = 1, #b.data do
            local b = b.data[i]

            ok = a:Equal(b)
            
            if ok then
                break    
            end
        end
        if not ok then
            a.suppress = false
            return false
        end
    end
    a.suppress = false
    
    return true
end

function META:SortNow()
    if self.sort_me then
        table.sort(self.data, sort)
        self.sort_me = false
    end
end

function META:GetSignature()
    self:SortNow()

    if self.suppress then
        return "*"
    end

    local s = {}

    self.suppress = true
    for i, v in ipairs(self.data) do
        s[i] = v:GetSignature()
    end
    self.suppress = false

    return table.concat(s)
end

function META:__tostring()
    self:SortNow()

    if self.suppress then
        return "*self-union*"
    end

    local s = {}

    self.suppress = true
    for _, v in ipairs(self.data) do
        table.insert(s, tostring(v))
    end
    self.suppress = false

    return table.concat(s, " | ")
end

function META:AddType(e)
    if e.Type == "union" then
        for _, v in ipairs(e.data) do
            self:AddType(v)
        end
        return self
    end

    for _, v in ipairs(self.data) do
        if v:Equal(e) then
            return self
        end
    end

    table.insert(self.data, 1, e)

    self:Sort()

    if #self.data > 512 then 
        error("union is too large", 2)
    end

    return self
end

function META:GetData()
    return self.data
end

function META:GetLength()
    return #self.data
end

function META:RemoveType(e)
    if e.Type == "union" then
        for i,v in ipairs(e.data) do
            self:RemoveType(v)
        end
        return self
    end
    for i,v in ipairs(self.data) do
        if v:Equal(e) then
            table.remove(self.data, i)
            self:Sort()
            break
        end
    end

    return self
end


function META:Clear()
    self.data = {}
end

function META:GetMinimumLength()
    local min = 1000

    for _, obj in ipairs(self.data) do
        if obj.Type == "tuple" then
            min = math.min(min, obj:GetMinimumLength())
        else
            min = math.min(min, 1)
        end
    end

    return min
end

function META:GetAtIndex(i)
    local val
    local errors = {}
    
    for _, obj in ipairs(self.data) do
        if obj.Type == "tuple" then
            local found, err = obj:Get(i)
            if found then
                if val then
                    val = types.Union({val, found})
                    val:SetNode(found:GetNode()):SetSource(found):SetBinarySource(found.source_left, found.source_right)
                else
                    val = found
                end
            else
                if val then
                    val = types.Union({val, types.Nil()})
                else
                    val = types.Nil()
                end

                table.insert(errors, err)
            end
        else
            if val then
                val = types.Union({val, obj})
                val:SetNode(self:GetNode()):SetSource(self):SetBinarySource(self.source_left, self.source_right)
            else
                val = obj
            end
        end
    end
    
    if not val then
        return false, errors
    end

    return val
end

function META:Get(key, from_table)
    key = types.Cast(key)

    if from_table then
        for _, obj in ipairs(self.data) do
            if obj.Get then
                local val = obj:Get(key)
                if val then
                    return val
                end
            end
        end
    end

    local errors = {}

    for _, obj in ipairs(self.data) do
        local ok, reason = key:IsSubsetOf(obj)

        if ok then
            return obj
        end

        table.insert(errors, reason)
    end

    return type_errors.other(errors)
end

function META:IsEmpty()
    return self.data[1] == nil
end

function META:IsTruthy()
    if self:IsEmpty() then return false end

    for _, obj in ipairs(self.data) do
        if obj:IsTruthy() then
            return true
        end
    end
    return false
end

function META:IsFalsy()
    if self:IsEmpty() then return false end

    for _, obj in ipairs(self.data) do
        if obj:IsFalsy() then
            return true
        end
    end
    return false
end

function META:GetTruthy()
    local copy = self:Copy()
    for _, obj in ipairs(self.data) do
        if not obj:IsTruthy() then
            copy:RemoveType(obj)
        end
    end
    return copy
end

function META:GetFalsy()
    local copy = self:Copy()
    for _, obj in ipairs(self.data) do
        if not obj:IsFalsy() then
            copy:RemoveType(obj)
        end
    end
    return copy
end

function META:IsType(typ)
    if self:IsEmpty() then return false end

    for _, obj in ipairs(self.data) do
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
    for _, obj in ipairs(self.data) do
        if obj.Type == "symbol" and obj:GetData() == nil then
            return true
        end
    end
    return false
end

function META:GetType(typ)
    for _, obj in ipairs(self.data) do
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
            --return type_errors.subset(A, B, "a tuple cannot be a subset of another tuple")
        end
        -- TODO: given error above, the unpack probably should probably be moved out
    end


    if B.Type ~= "union" then
        return A:IsSubsetOf(types.Union({B}))
    end

    for _, a in ipairs(A.data) do
        local b, reason = B:Get(a)

        if not b then
            return type_errors.missing(B, a, reason)
        end

        local ok, reason = a:IsSubsetOf(b)

        if not ok then
            return type_errors.subset(a, b, reason)
        end
    end

    return true
end

function META:Union(union)
    local copy = self:Copy()

    for _, e in ipairs(union.data) do
        copy:AddType(e)
    end

    return copy
end

function META:Intersect(union)
    local copy = types.Union()

    for _, e in ipairs(self.data) do
        if union:Get(e) then
            copy:AddType(e)
        end
    end

    return copy
end

function META:Subtract(union)
    local copy = self:Copy()

    for _, e in ipairs(self.data) do
        copy:RemoveType(e)
    end

    return copy
end

function META:Copy(map)
    map = map or {}
    local copy = types.Union()
    map[self] = map[self] or copy

    for _, e in ipairs(self.data) do
        local c = map[e] or e:Copy(map)
        map[e] = map[e] or c
        copy:AddType(c)
    end

    copy:Sort()
    copy:CopyInternalsFrom(self)

    table.sort(copy.data, sort)
    copy.sort_me = false

    return copy
end

function META:IsTruthy()
    for _, v in ipairs(self.data) do
        if v:IsTruthy() then
            return true
        end
    end

    return false
end


function META:IsFalsy()
    for _, v in ipairs(self.data) do
        if v:IsFalsy() then
            return true
        end
    end

    return false
end

function META:DisableTruthy()
    local found = {}
    for _, v in ipairs(self.data) do
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
    for _, v in ipairs(self.data) do
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
    self:Clear()

    if data then
        for _, v in ipairs(data) do
            self:AddType(v)
        end
    end

    return true
end

function META:SetMax(val)
    local copy = self:Copy()
    for _, e in ipairs(copy.data) do
        e:SetMax(val)
    end
    return copy
end

function META:Call(analyzer, arguments, ...)
    if self:IsEmpty() then
        return type_errors.operation("call", nil)
    end

    local union = self
    for _, obj in ipairs(self.data) do
        if obj.Type ~= "function" and obj.Type ~= "table" and obj.Type ~= "any" then
            return type_errors.operation("call", obj)
        end
    end

    local errors = {}

    for _, obj in ipairs(self.data) do
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

    return type_errors.other(errors)
end

function META:MakeCallableUnion(analyzer, node)
    local new_union = types.Union()
    local truthy_union = types.Union()
    local falsy_union = types.Union()

    for _, v in ipairs(self.data) do               
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

    return truthy_union:SetNode(node):SetSource(new_union):SetBinarySource(self)
end

return META