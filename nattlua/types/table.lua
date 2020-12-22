local types = require("nattlua.types.types")

local META = {}
META.Type = "table"
META.__index = META


function META:GetLuaType()
    return self.Type
end

function META:GetSignature()
    if self:IsUnique() then
        return tostring(self:GetUniqueID())
    end

    if self:GetContract() and self:GetContract().Name then
        self.suppress = nil
        return self:GetContract().Name:GetData()
    end

    if self.Name then
        self.suppress = nil
        return self.Name:GetData()
    end

    if self.suppress then
        return "*"
    end

    self.suppress = true

    local s = {}
    local i = 1
    for _, keyval in ipairs(self:GetContract() or self.data) do
        s[i] = keyval.key:GetSignature() 
        i = i + 1
        s[i] = keyval.val:GetSignature()
        i = i + 1
    end
    self.suppress = false

    s = table.concat(s)

    return s
end

local level = 0
function META:__tostring()
    if self.suppress then
        return "*self*"
    end

    self.suppress = true

    if self:GetContract() and self:GetContract().Name then
        self.suppress = nil
        return self:GetContract().Name:GetData()
    end

    if self.Name then
        self.suppress = nil
        return self.Name:GetData()
    end

    local s = {}

    level = level + 1
    local indent = ("\t"):rep(level)

    if self:GetContract() and self:GetContract().Type == "table" then
        for i, keyval in ipairs(self:GetContract().data) do
            local key, val = tostring(self.data[i] and self.data[i].key or "undefined"), tostring(self.data[i] and self.data[i].val or "undefined")
            local tkey, tval = tostring(keyval.key), tostring(keyval.val)
            s[i] = indent .. tkey .. " ⊃ ".. key .. " = " .. tval .. " ⊃ " .. val
        end
    else
        for i, keyval in ipairs(self.data) do
            local key, val = tostring(keyval.key), tostring(keyval.val)
            s[i] = indent .. key .. " = " .. val
        end
    end
    level = level - 1
    self.suppress = false

    if #self.data == 1 then
        return "{" .. table.concat(s, ""):gsub("\t", " ") .. " }"
    end
    
    return "{\n" .. table.concat(s, ",\n") .. "\n" .. ("\t"):rep(level) .. "}"
end

function META:GetLength()
    return #self.data
end

function META:FollowsContract(contract)
    for _, keyval in ipairs(contract:GetData()) do
        local res, err = self:GetKeyVal(keyval.key)

        if not res and self:GetMetaTable() then
            res, err = self:GetMetaTable():GetKeyVal(keyval.key)
        end

        if not res then
            return res, err
        end

        local ok, err = res.val:IsSubsetOf(keyval.val)
        if not ok then
            return ok, err
        end
    end

    return true
end

function META.IsSubsetOf(A, B)
    if A.suppress then
        return true
    end

    if B.Type == "any" then
        return true
    end

    local ok, err = types.IsSameUniqueType(A, B)
    if not ok then
        return ok, err
    end

    if A == B then
        return true
    end

    if B.Type == "tuple" then
        if not A:IsNumericallyIndexed() then
            return types.errors.other("cannot compare against tuple when I'm not numerically indexed")
        end

        if B:GetLength() > 0 then
            for i, a in ipairs(A.data) do
                if a.key.Type == "number" then
                    local b, reason = B:Get(i)

                    if not b then
                        return types.errors.missing(B, a.key, reason)
                    end

                    A.suppress = true
                    local ok, reason = a.val:IsSubsetOf(b)
                    A.suppress = false

                    if not ok then
                        return types.errors.subset(a.val, b, reason)
                    end
                end
            end
        end

        return true
    elseif B.Type == "table" then

        if B:GetMetaTable() and B:GetMetaTable() == A then
            return true
        end

        local can_be_empty = true
        A.suppress = true
        for _, keyval in ipairs(B:GetData()) do
            if not types.Nil():IsSubsetOf(keyval.val) then
                can_be_empty = false
                break
            end
        end
        A.suppress = false

        if not A.data[1] and (not A:GetContract() or not A:GetContract().data[1]) then
            if can_be_empty then
                return true
            else
                return types.errors.other("table is empty")
            end
        end

        for _, akeyval in ipairs(A:GetData()) do
            local bkeyval, reason = B:GetKeyVal(akeyval.key, true) 
            if not bkeyval then
                return bkeyval, reason
            end
        
            A.suppress = true
            local ok, err = akeyval.val:IsSubsetOf(bkeyval.val)
            A.suppress = false

            if not ok then
                return types.errors.subset(akeyval.val, bkeyval.val, err)
            end
        end
        
        return true
    elseif B.Type == "union" then
        A.suppress = true
        local u = types.Union({A}):IsSubsetOf(B)
        A.suppress = false
        return u
    end

    return types.errors.subset(A, B)
end

function META:ContainsAllKeysIn(contract)
    for _, keyval in ipairs(contract.data) do
        if keyval.key:IsLiteral() then
            local ok, err = self:GetKeyVal(keyval.key)
            if not ok then
                
                if (keyval.val.Type == "symbol" and keyval.val.data == nil) or (keyval.val.Type == "union" and keyval.val:HasNil()) then
                    return true
                end

                return types.errors.other(tostring(keyval.key) .. " is missing from " .. tostring(contract))
            end
        end
    end
    return true
end

function META:IsDynamic()
    return true
end

function META:Delete(key)
    for i, keyval in ipairs(self.data) do
        if key:IsSubsetOf(keyval.key) and keyval.key:IsLiteral() then
            keyval.val:SetParent()
            keyval.key:SetParent()
            table.remove(self.data, i)
        end
    end
    return true
    --return types.errors.other("cannot remove " .. tostring(key) .. " from table because it was not found in " .. tostring(self))
end

function META:GetKeyUnion()
    local union = types.Union()

    for _, keyval in ipairs(self.data) do
        union:AddType(keyval.key:Copy())
    end

    return union
end

function META:Contains(key)
    key = types.Cast(key)

    return self:GetKeyVal(key, true)
end

function META:GetKeyVal(key, reverse_subset)
    if not self.data[1] then
        return types.errors.missing(self, key, "table is empty")
    end

    local reasons = {}

    for _, keyval in ipairs(self.data) do
        local ok, reason

        if reverse_subset then
            ok, reason = key:IsSubsetOf(keyval.key)
        else
            ok, reason = keyval.key:IsSubsetOf(key)
        end

        if ok then
            return keyval
        end
        
        table.insert(reasons, reason)
    end

    return types.errors.missing(self, key, reasons)
end

function META:Insert(val)
    self.size = self.size or 1
    self:Set(self.size, val)
    self.size = self.size + 1
end

function META:GetEnvironmentValues()
    local values = {}
    for i, keyval in ipairs(self.data) do
        values[i] = keyval.val
    end
    return values
end

function META:Set(key, val, no_delete)
    key = types.Cast(key)
    val = types.Cast(val)

    if key.Type == "string" and key:IsLiteral() and key:GetData():sub(1,1) == "@" then
        self["Set" .. key:GetData():sub(2)](self, val)
        return true
    end

    if key.Type == "symbol" and key:GetData() == nil then
        return types.errors.other("key is nil")
    end

    if key.Type == "union" then
        local union = key
        for _, key in ipairs(union:GetTypes()) do
            if key.Type == "symbol" and key:GetData() == nil then
                return types.errors.other(union:GetLength() == 1 and "key is nil" or "key can be nil")
            end

            self:Set(key, val, no_delete)
        end
        return true
    end

    -- delete entry
    if not no_delete and not self:GetContract() then
        if (val == nil or (val.Type == "symbol" and val:GetData() == nil)) then
            return self:Delete(key)
        end
    end

    if self:GetContract() and self:GetContract().Type == "table" then -- TODO
        local keyval, reason = self:GetContract():GetKeyVal(key, true)

        if not keyval then
            return keyval, reason
        end

        local keyval, reason = val:IsSubsetOf(keyval.val)

        if not keyval then
            return keyval, reason
        end
    end

    -- if the key exists, check if we can replace it and maybe the value
    local keyval, reason = self:GetKeyVal(key, true)

    if not keyval then
        val:SetParent(self)
        key:SetParent(self)
        table.insert(self.data, {key = key, val = val})
        if #self.data > 512 then 
            error("table is too large", 2)
        end
    else
        if keyval.val and keyval.key:GetSignature() ~= key:GetSignature() then
            keyval.val = types.Union({keyval.val, val})
        else
            keyval.val = val
        end
    end

    return true
end

function META:Get(key)
    key = types.Cast(key)

    if key.Type == "union" then
        local errors = {}
        for _, k in ipairs(key:GetTypes()) do
            local ok, reason = self:Get(k)
            if ok then
                return ok
            end
            table.insert(errors, reason)
        end
        return types.errors.other(errors)
    end

    if key.Type == "string" and not key:IsLiteral() then
        local union = types.Union({types.Nil()})
        for _, keyval in ipairs(self:GetData()) do
            if keyval.key.Type == "string" then
                union:AddType(keyval.val)
            end
        end
        return union
    end

    if key.Type == "number" and not key:IsLiteral() then
        local union = types.Union({types.Nil()})
        for _, keyval in ipairs(self:GetData()) do
            if keyval.key.Type == "number" then
                union:AddType(keyval.val)
            end
        end
        return union
    end

    local keyval, reason = self:GetKeyVal(key, true)
    
    if keyval then
        return keyval.val
    end

    if not keyval and self:GetContract() then
        local keyval, reason = self:GetContract():GetKeyVal(key, true)
        if keyval then
            return keyval.val
        end
        
        return types.errors.other(reason)
    end

    return types.errors.other(reason)
end

function META:IsNumericallyIndexed()

    for _, keyval in ipairs(self:GetData()) do
        if keyval.key.Type ~= "number" then
            return false
        end
    end

    return true
end

function META:CopyLiteralness(from)
    for _, keyval_from in ipairs(from.data) do
        local keyval, reason = self:GetKeyVal(keyval_from.key)

        if not keyval then
            return types.errors.other(reason)
        end

        if keyval_from.key.Type == "table" then
            keyval.key:CopyLiteralness(keyval_from.key)
        else
            keyval.key:MakeLiteral(keyval_from.key:IsLiteral())
        end

        if keyval_from.val.Type == "table" then
            keyval.val:CopyLiteralness(keyval_from.val)
        else
            keyval.val:MakeLiteral(keyval_from.val:IsLiteral())
        end
    end
    return true
end

function META:Copy(map)
    map = map or {}

    local copy = types.Table({})
    map[self] = map[self] or copy

    copy.node = self.node

    for i, keyval in ipairs(self.data) do
        local k, v = keyval.key, keyval.val

        k = map[keyval.key] or k:Copy(map)
        map[keyval.key] = map[keyval.key] or k

        v = map[keyval.val] or v:Copy(map)
        map[keyval.val] = map[keyval.val] or v
                
        copy.data[i] = {key = k, val = v}
    end

    copy:CopyInternalsFrom(self)

    return copy
end

function META:GetData()
    return self.data
end

function META:pairs()
    local i = 1
    return function()
        local keyval = self.data and self.data[i] or self:GetContract() and self:GetContract()[i]

        if not keyval then
            return nil
        end

        i = i + 1

        return keyval.key, keyval.val
    end
end

function META:HasLiteralKeys()
    if self.suppress then
        return true
    end

    for _, v in ipairs(self.data) do
        if v.val ~= self and v.key ~= self and v.val.Type ~= "function" and v.key.Type ~= "function" then

            self.suppress = true
            local ok, reason = v.key:IsLiteral()
            self.suppress = false

            if not ok then
                return types.errors.other("the key " .. tostring(v.key) .. " is not a literal because " .. tostring(reason))
            end
        end
    end

    return true
end

function META:IsLiteral()
    if self.suppress then
        return true
    end

    if self:GetContract() then
        return false
    end

    for _, v in ipairs(self.data) do
        if v.val ~= self and v.key ~= self and v.val.Type ~= "function" and v.key.Type ~= "function" then

            self.suppress = true
            local ok, reason = v.key:IsLiteral()
            self.suppress = false

            if not ok then
                return types.errors.other("the key " .. tostring(v.key) .. " is not a literal because " .. tostring(reason))
            end

            self.suppress = true
            local ok, reason = v.val:IsLiteral()
            self.suppress = false

            if not ok then
                return types.errors.other("the value " .. tostring(v.val) .. " is not a literal because " .. tostring(reason))
            end
        end
    end

    return true
end

function META:IsFalsy()
    return false
end

function META:IsTruthy()
    return true
end

local function unpack_keyval(keyval, tbl)
    local key, val = keyval.key, keyval.val
    return key, val
end

function META.Extend(A, B, dont_copy_self)
    
    if B.Type ~= "table" then
        return false, "cannot extend non table"
    end

    local map = {}

    if not dont_copy_self then
        A = A:Copy(map)
    end
    
    map[B] = A
    B = B:Copy(map)

    for _, keyval in ipairs(B:GetData()) do
        if not A:Get(keyval.key) then
            A:Set(unpack_keyval(keyval, B))
        end
    end

    return A
end

function META.Union(A, B)
    local copy = types.Table({})

    for _, keyval in ipairs(A:GetData()) do
        copy:Set(unpack_keyval(keyval, A, copy))
    end

    for _, keyval in ipairs(B:GetData()) do
        copy:Set(unpack_keyval(keyval, B, copy))
    end

    return copy
end

function META:Initialize(data)
    self.data = {}

    if data then
        for _, v in ipairs(data) do
            local ok, err = self:Set(v.key, v.val)
            if not ok then
                return ok, err
            end
        end
    end

    return true
end

function META:Call(analyzer, arguments, ...)
    local __call = self:GetMetaTable() and self:GetMetaTable():Get("__call")

    if __call then
        local new_arguments = {self}

        for _, v in ipairs(arguments:GetData()) do
            table.insert(new_arguments, v)
        end

        return analyzer:Call(__call, types.Tuple(new_arguments), ...)
    end

    return types.errors.other("table has no __call metamethod")
end

return types.RegisterType(META)