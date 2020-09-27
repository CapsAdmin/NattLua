local types = require("oh.typesystem.types")

local META = {}
META.Type = "table"
META.__index = META

local function sort(a, b) return a < b end

function META:GetLuaType()
    return self.Type
end

function META:GetSignature()
    if self.suppress then
        return "*self*"
    end

    local s = {}

    self.suppress = true
    for i, keyval in ipairs(self.data) do
        s[i] = keyval.key:GetSignature() .. "=" .. keyval.val:GetSignature()
    end
    self.suppress = nil

    table.sort(s, sort)

    if self:IsUnique() then
        table.insert(s, tostring(self:GetUniqueID()))
    end

    return table.concat(s, "\n")
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

    if self.contract then
        for i, keyval in ipairs(self.contract.data) do
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

    self.suppress = nil

    table.sort(s, sort)

    if #self.data == 1 then
        return "{" .. table.concat(s, ""):gsub("\t", " ") .. " }"
    end
    
    return "{\n" .. table.concat(s, ",\n") .. "\n" .. ("\t"):rep(level) .. "}"
end

function META:GetLength()
    return #self.data
end

-- TODO
local done

function META.SubsetOf(A, B)
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
        if B:GetLength() > 0 then
            for i, a in ipairs(A.data) do
                if a.key.Type == "number" then
                    if not B:Get(i) then
                        return types.errors.missing(B, i)
                    end

                    if not a.val:SubsetOf(B:Get(i)) then
                        return types.errors.subset(a.val, B:Get(i))
                    end
                end
            end
        else
            local count = 0
            for i, a in ipairs(A.data) do
                if a.key.data ~= i then
                    return types.errors.other("index " .. tostring(a.key) .. " is not the same as " .. tostring(i))
                end

                count = count + 1
            end
            if count ~= B:GetMaxLength() then
                return types.errors.other(" count " .. tostring(count) .. " is not the same as max length " .. tostring(B:GetMaxLength()))
            end
        end

        return true
    elseif B.Type == "table" then

        if B.meta and B.meta == A then
            return true
        end

        done = done or {}

        for _, a in ipairs(A.data) do
            local b
            do
                local reasons = {}

                if not B.data[1] then
                    return types.errors.other("table is empty")
                end

                for _, keyval in ipairs(B.data) do
                    local ok, reason = a.key:SubsetOf(keyval.key)
                    if ok then
                        b = keyval
                        break
                    end
                    table.insert(reasons, reason)
                end

                if not b then
                    return types.errors.other(table.concat(reasons, "\n"))
                end
            end

            local key = a.val:GetSignature() .. b.val:GetSignature()
            if not done or not done[key] then
                if done then
                    done[key] = true
                end

                local ok, reason = a.val:SubsetOf(b.val)
                if not ok then
                    return types.errors.subset(a.val, b.val, reason)
                end
            end
        end
        done = nil

        return true
    elseif B.Type == "set" then
        return types.Set({A}):SubsetOf(B)
    end

    return types.errors.subset(A, B)
end

function META:ContainsAllKeysIn(contract)
    for _, keyval in ipairs(contract.data) do
        if keyval.key:IsLiteral() then
            local ok, err = self:GetKeyVal(keyval.key)
            if not ok then
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
        if key:SubsetOf(keyval.key) then
            table.remove(self.data, i)
        end
    end
    return true
    --return types.errors.other("cannot remove " .. tostring(key) .. " from table because it was not found in " .. tostring(self))
end

function META:GetKeySet()
    local set = types.Set()

    for _, keyval in ipairs(self.data) do
        set:AddElement(keyval.key:Copy())
    end

    return set
end

function META:Contains(key)
    return self:GetKeyVal(key, true)
end

function META:GetKeyVal(key, reverse_subset)
    if not self.data[1] then
        return types.errors.other("table has no definitions")
    end

    local reasons = {}

    for _, keyval in ipairs(self.data) do
        local ok, reason

        if reverse_subset then
            ok, reason = key:SubsetOf(keyval.key)
        else
            ok, reason = keyval.key:SubsetOf(key)
        end

        if ok then
            return keyval
        end
        table.insert(reasons, reason)
    end

    return types.errors.other(table.concat(reasons, "\n"))
end

function META:Insert(val)
    self.size = self.size or 1
    self:Set(self.size, val)
    self.size = self.size + 1
end

function META:GetValues()
    local values = {}
    for i, keyval in ipairs(self.data) do
        values[i] = keyval.val
    end
    return values
end

function META:Set(key, val)
    key = types.Cast(key)
    val = types.Cast(val)

    if key.Type == "symbol" and key:GetData() == nil then
        return types.errors.other("key is nil")
    end

    if key.Type == "set" then
        local set = key
        for _, key in ipairs(set:GetElements()) do
            if key.Type == "symbol" and key:GetData() == nil then
                return types.errors.other(set:GetLength() == 1 and "key is nil" or "key can be nil")
            end
        end
    end

    -- delete entry
    if val == nil or (val.Type == "symbol" and val:GetData() == nil) then
        return self:Delete(key)
    end

    if self.contract then
        local keyval, reason = self.contract:GetKeyVal(key, true)

        if not keyval then
            return keyval, reason
        end

        local keyval, reason = val:SubsetOf(keyval.val)

        if not keyval then
            return keyval, reason
        end
    end

    -- shortcut for setting a metatable on a type
    -- type tbl = { }; setmetatable<|tbl, tbl|>
    -- becomes
    -- type tbl = { __meta = self }
    if key.Type == "string" and key:IsLiteral() and key:GetData() == "__meta" then
        self.meta = val
    end

    -- if the key exists, check if we can replace it and maybe the value
    local keyval, reason = self:GetKeyVal(key, true)

    if not keyval then
        table.insert(self.data, {key = key, val = val})
    else
        if keyval.val and keyval.key:GetSignature() ~= key:GetSignature() then
            keyval.val = types.Set({keyval.val, val})
        else
            keyval.val = val
        end
    end

    return true
end

function META:Get(key)
    key = types.Cast(key)

    if key.Type == "string" and not key:IsLiteral() then
        local set = types.Set({types.Nil})
        for _, keyval in ipairs(self:GetData()) do
            if keyval.key.Type == "string" then
                set:AddElement(keyval.val)
            end
        end
        return set
    end

    if key.Type == "number" and not key:IsLiteral() then
        local set = types.Set({types.Nil})
        for _, keyval in ipairs(self:GetData()) do
            if keyval.key.Type == "number" then
                set:AddElement(keyval.val)
            end
        end
        return set
    end

    local keyval, reason = self:GetKeyVal(key, true)

    if keyval then
        return keyval.val
    end

    if not keyval and self.contract then
        local keyval, reason = self.contract:GetKeyVal(key, true)
        if keyval then
            return keyval.val
        end
    end

    return types.errors.other(reason)
end

function META:IsNumericallyIndexed()

    for _, keyval in ipairs(self:GetElements()) do
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

    for _, keyval in ipairs(self.data) do
        local k, v = keyval.key, keyval.val

        k = map[keyval.key] or k:Copy(map)
        map[keyval.key] = map[keyval.key] or k

        v = map[keyval.val] or v:Copy(map)
        map[keyval.val] = map[keyval.val] or v
                
        copy:Set(k, v)
    end

    copy.meta = self.meta

    return copy
end

function META:GetData()
    return self.data
end

function META:pairs()
    local i = 1
    return function()
        local keyval = self.data and self.data[i]

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

function META.Extend(A, B)
    local map = {}
    A = A:Copy(map)
    
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

return types.RegisterType(META)