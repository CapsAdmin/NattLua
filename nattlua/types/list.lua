local types = require("nattlua.types.types")
local type_errors = require("nattlua.types.error_messages")

local META = {}
META.Type = "list"
META.__index = META

local function sort(a, b) return a < b end

function META:GetSignature()
    if self.suppress then
        return "*self*"
    end

    local s = {}

    self.suppress = true
    for i, keyval in ipairs(self:GetData()) do
        s[i] = keyval.key:GetSignature() .. "=" .. keyval.val:GetSignature()
    end
    self.suppress = nil

    return "[" .. table.concat(s, "\n") .. "]"
end

local level = 0
function META:__tostring()
    if self.suppress then
        return "*self*"
    end
    self.suppress = true

    local s = {}

    level = level + 1
    local indent = ("\t"):rep(level)

    if self:GetContract() then
        for i, keyval in ipairs(self:GetContract():GetData()) do
            local key, val = tostring(self:GetData()[i] and self:GetData()[i].key or "undefined"), tostring(self:GetData()[i] and self:GetData()[i].val or "undefined")
            local tkey, tval = tostring(keyval.key), tostring(keyval.val)
            s[i] = indent .. tkey .. " ⊃ ".. key .. " = " .. tval .. " ⊃ " .. val
        end
    else
        for i, keyval in ipairs(self:GetData()) do
            local key, val = tostring(keyval.key), tostring(keyval.val)
            s[i] = indent .. key .. " = " .. val
        end
    end
    level = level - 1

    self.suppress = nil

    table.sort(s, sort)

    if #self:GetData() == 1 then
        return "[" .. table.concat(s, ""):gsub("\t", " ") .. " ]"
    end
    
    return "[\n" .. table.concat(s, ",\n") .. "\n" .. ("\t"):rep(level) .. "]"
end

function META:GetLength()
    return #self:GetData()
end

-- TODO
local done

function META.IsSubsetOf(A, B)
    if A == B then
        return true
    end

    if B.Type == "any" then
        return true
    end

    if B.Type == "tuple" then
        if B:GetLength() > 0 then
            for i, a in ipairs(A:GetData()) do
                if a.key.Type == "number" then
                    local b, reason = B:Get(i)
                    if not b then
                        return type_errors.missing(B, i, reason)
                    end

                    if not a.val:IsSubsetOf(b) then
                        return type_errors.subset(a.val, b)
                    end
                end
            end
        else
            local count = 0
            for i, a in ipairs(A:GetData()) do
                if a.key:GetData() ~= i then
                    return type_errors.other("index " .. tostring(a.key) .. " is not the same as " .. tostring(i))
                end

                count = count + 1
            end
            if count ~= B:GetMaxLength() then
                return type_errors.other(" count " .. tostring(count) .. " is not the same as max length " .. tostring(B:GetMaxLength()))
            end
        end

        return true
    elseif B.Type == "list" then

        if B:GetMetaTable() and B:GetMetaTable() == A then
            return true
        end

        done = done or {}

        for _, a in ipairs(A:GetData()) do
            local b
            do
                local reasons = {}

                if not B:GetData()[1] then
                    return type_errors.other("list is empty")
                end

                for _, keyval in ipairs(B:GetData()) do
                    local ok, reason = a.key:IsSubsetOf(keyval.key)
                    if ok then
                        b = keyval
                        break
                    end
                    table.insert(reasons, reason)
                end

                if not b then
                    return type_errors.other(reasons)
                end
            end

            local key = a.val:GetSignature() .. b.val:GetSignature()
            if not done or not done[key] then
                if done then
                    done[key] = true
                end

                local ok, reason = a.val:IsSubsetOf(b.val)
                if not ok then
                    return type_errors.subset(a.val, b.val, reason)
                end
            end
        end
        done = nil

        return true
    elseif B.Type == "union" then
        return types.Union({A}):IsSubsetOf(B)
    end

    return type_errors.subset(A, B)
end

function META:ContainsAllKeysIn(contract)
    for _, keyval in ipairs(contract:GetData()) do
        if keyval.key:IsLiteral() then
            local ok, err = self:GetKeyVal(keyval.key)
            if not ok then
                return type_errors.other(tostring(keyval.key) .. " is missing from " .. tostring(contract))
            end
        end
    end
    return true
end

function META:IsDynamic()
    return true
end

function META:Delete(key)
    for i, keyval in ipairs(self:GetData()) do
        if key:IsSubsetOf(keyval.key) then
            table.remove(self:GetData(), i)
        end
    end
    return true
    --return type_errors.other("cannot remove " .. tostring(key) .. " from table because it was not found in " .. tostring(self))
end

function META:GetKeyUnion()
    local union = types.Union()

    for _, keyval in ipairs(self:GetData()) do
        union:AddType(keyval.key:Copy())
    end

    return union
end

function META:Contains(key)
    if self.ElementType then 
        return true
    end

    return self:GetKeyVal(key, true)
end

function META:GetKeyVal(key, reverse_subset)
    if not self:GetData()[1] then

        return type_errors.other("list has no definitions")
    end

    if key.Type ~= "number" then
        return type_errors.other("cannot index list with " .. tostring(key))
    end

    local reasons = {}

    for _, keyval in ipairs(self:GetData()) do
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

    return type_errors.other(reasons)
end

function META:Insert(val)
    return self:Set(#self:GetData() + 1, val)
end

function META:Set(key, val)
    key = types.Cast(key)
    val = types.Cast(val)

    if key.Type == "symbol" and key:GetData() == nil then
        return type_errors.other("key is nil")
    end

    if key.Type == "union" then
        local union = key
        for _, key in ipairs(union:GetTypes()) do
            if key.Type == "symbol" and key:GetData() == nil then
                return type_errors.other(union:GetLength() == 1 and "key is nil" or "key can be nil")
            end
        end
    end

    -- delete entry
    if val == nil or (val.Type == "symbol" and val:GetData() == nil) then
        return self:Delete(key)
    end

    if self:GetContract() then
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
        table.insert(self:GetData(), {key = key, val = val})
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

    if self.ElementType then
        return self.ElementType
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
        if self:GetContract().ElementType then
            return self:GetContract().ElementType
        end

        local keyval, reason = self:GetContract():GetKeyVal(key, true)
        if keyval then
            return keyval.val
        end
    end

    return type_errors.other(reason)
end

function META:IsNumericallyIndexed()

    for _, keyval in ipairs(self:GetTypes()) do
        if keyval.key.Type ~= "number" then
            return false
        end
    end

    return true
end

function META:CopyLiteralness(from)
    for _, keyval_from in ipairs(from:GetData()) do
        local keyval, reason = self:GetKeyVal(keyval_from.key)

        if not keyval then
            return type_errors.other(reason)
        end

        if keyval_from.key.Type == "list" then
            keyval.key:CopyLiteralness(keyval_from.key)
        else
            keyval.key:SetLiteral(keyval_from.key:IsLiteral())
        end

        if keyval_from.val.Type == "list" then
            keyval.val:CopyLiteralness(keyval_from.val)
        else
            keyval.val:SetLiteral(keyval_from.val:IsLiteral())
        end
    end
    return true
end

function META:Copy(map)
    map = map or {}

    local copy = types.List({})
    map[self] = map[self] or copy

    for _, keyval in ipairs(self:GetData()) do
        local k, v = keyval.key, keyval.val

        k = map[keyval.key] or k:Copy(map)
        map[keyval.key] = map[keyval.key] or k

        v = map[keyval.val] or v:Copy(map)
        map[keyval.val] = map[keyval.val] or v
                
        copy:Set(k, v)
    end

    copy:SetMetaTable(self:GetMetaTable())
    copy:CopyInternalsFrom(self)

    return copy
end

function META:pairs()
    local i = 1
    return function()
        local keyval = self:GetData() and self:GetData()[i]

        if not keyval then
            return nil
        end

        i = i + 1

        return keyval.key, keyval.val
    end
end

function META:IsLiteral()
    if self.suppress then
        return true
    end

    for _, v in ipairs(self:GetData()) do
        if v.val ~= self and v.key ~= self and v.val.Type ~= "function" and v.key.Type ~= "function" then

            self.suppress = true
            local ok, reason = v.key:IsLiteral()
            self.suppress = false

            if not ok then
                return type_errors.other("the key " .. tostring(v.key) .. " is not a literal because " .. tostring(reason))
            end

            self.suppress = true
            local ok, reason = v.val:IsLiteral()
            self.suppress = false

            if not ok then
                return type_errors.other("the value " .. tostring(v.val) .. " is not a literal because " .. tostring(reason))
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

local function unpack_keyval(keyval, tbl, copy)
    local key, val = keyval.key, keyval.val

    if key == tbl then
        key = copy
    else
        key = key:Copy(copy, tbl)
    end

    if val == tbl then
        val = copy
    else
        val = val:Copy(copy, tbl)
    end

    return key, val
end

function META.Extend(A, B)
    local copy = A:Copy()

    for _, keyval in ipairs(B:GetData()) do
        if not copy:Get(keyval.key) then
            copy:Set(unpack_keyval(keyval, B, copy))
        end
    end

    return copy
end

function META.Union(A, B)
    local copy = types.List({})

    for _, keyval in ipairs(A:GetData()) do
        copy:Set(unpack_keyval(keyval, A, copy))
    end

    for _, keyval in ipairs(B:GetData()) do
        copy:Set(unpack_keyval(keyval, B, copy))
    end

    return copy
end

function META:Initialize(data)
    self:SetData({})

    if data then
        for _, val in ipairs(data) do
            local ok, err = self:Insert(val)
            if not ok then
                return ok, err
            end
        end
    end

    return true
end

return types.RegisterType(META)