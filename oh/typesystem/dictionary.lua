local types = require("oh.typesystem.types")

local Dictionary = {}
Dictionary.Type = "dictionary"
Dictionary.__index = Dictionary

function Dictionary:GetSignature()
    if self.supress then
        return "*self*"
    end
    self.supress = true

    local s = {}

    for i, keyval in ipairs(self.data) do
        s[i] = keyval.key:GetSignature() .. "=" .. keyval.val:GetSignature()
    end
    self.supress = nil

    table.sort(s, function(a, b) return a > b end)

    return table.concat(s, "\n")
end

local level = 0
function Dictionary:Serialize()
    if self.supress then
        return "*self*"
    end
    self.supress = true

    local s = {}

    level = level + 1
    for i, keyval in ipairs(self.data) do
        local key, val = tostring(keyval.key), tostring(keyval.val)

        s[i] = ("\t"):rep(level) .. key .. " = " .. val
    end
    level = level - 1

    self.supress = nil

    table.sort(s, function(a, b) return a < b end)

    return "{\n" .. table.concat(s, ",\n") .. "\n" .. ("\t"):rep(level) .. "}"
end

function Dictionary:__tostring()
    if self.supress then
        return "*self*"
    end
    self.supress = true

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

    self.supress = nil

    table.sort(s, function(a, b) return a < b end)

    return "{\n" .. table.concat(s, ",\n") .. "\n" .. ("\t"):rep(level) .. "}"
end

function Dictionary:GetLength()
    return #self.data
end

-- TODO
local done

function Dictionary.SubsetOf(A, B)
    if A == B then
        return true
    end

    if B.type == "any" or B.volatile then
        return true
    end

    if B.Type == "tuple" then
        if B:GetLength() > 0 then
            for i, a in ipairs(A.data) do
                if a.key.type == "number" then
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
                    return false, "index " .. tostring(a.key.data) .. " is not the same as " .. tostring(i)
                end

                count = count + 1
            end
            if count ~= B:GetMaxLength() then
                return false, " count " .. tostring(count) .. " is not the same as max length " .. tostring(B:GetMaxLength())
            end
        end

        return true
    elseif B.Type == "dictionary" then

        if B.meta and B.meta == A then
            return true
        end

        done = done or {}
        for _, a in ipairs(A.data) do
            local b
            do
                local reasons = {}

                for _, keyval in ipairs(B.data) do
                    local ok, reason = a.key:SubsetOf(keyval.key)
                    if ok then
                        b = keyval
                        break
                    end
                    table.insert(reasons, reason)
                end

                if not b then
                    return false, table.concat(reasons, "\n")
                end
            end

            local key = a.val:Serialize() .. b.val:Serialize()
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
        return types.Set:new({A}):SubsetOf(B)
    end

    return types.errors.subset(A, B)
end

function Dictionary:IsDynamic()
    return true
end

function Dictionary:Union(dict)
    local copy = types.Dictionary:new({})

    for _, keyval in ipairs(self.data) do
        copy:Set(keyval.key, keyval.val)
    end

    for _, keyval in ipairs(dict.data) do
        copy:Set(keyval.key, keyval.val)
    end

    return copy
end

function Dictionary:Delete(key)
    for i, keyval in ipairs(self.data) do
        if key:SubsetOf(keyval.key) then
            table.remove(self.data, i)
            return true
        end
    end
    return false, "cannot remove " .. tostring(key) .. " from dictionary because it was not found in " .. tostring(self)
end

function Dictionary:GetKeySet()
    local set = types.Set:new()

    for _, keyval in ipairs(self.data) do
        set:AddElement(keyval.key:Copy())
    end

    return set
end

function Dictionary:Contains(key)
    return self:GetKeyVal(key, true)
end

function Dictionary:GetKeyVal(key, reverse_subset)
    if not self.data[1] then
        return false, "dictionary has no definitions"
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
            if keyval.val.self then
                keyval.val = self
            end

            return keyval
        end
        table.insert(reasons, reason)
    end

    return false, table.concat(reasons, "\n")
end

function Dictionary:Set(key, val, raw)
    key = types.Cast(key)
    val = types.Cast(val)

    if key.type == "nil" then
        return false, "key is nil"
    end

    -- delete entry
    if val == nil or val.type == "nil" then
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

    -- if the key exists, check if we can replace it and maybe the value
    local keyval, reason = self:GetKeyVal(key, true)

    if not keyval then
        table.insert(self.data, {key = key, val = val})
    else
        if keyval.val and keyval.key:Serialize() ~= key:Serialize() then
            keyval.val = types.Set:new({keyval.val, val})
        else
            keyval.val = val
        end
    end

    return true
end

function Dictionary:Get(key, raw)
    key = types.Cast(key)

    local keyval, reason = self:GetKeyVal(key, true)

    if keyval then
        return keyval.val
    end

    return false, reason
end

function Dictionary:IsNumericallyIndexed()

    for _, keyval in ipairs(self:GetElements()) do
        if keyval.key.type ~= "number" then
            return false
        end
    end

    return true
end

function Dictionary:CopyConstness(from)
    for _, keyval_from in ipairs(from.data) do
        local keyval, reason = self:GetKeyVal(keyval_from.key)

        if not keyval then
            return false, reason
        end

        if keyval_from.key.Type == "dictionary" then
            keyval.key:CopyConstness(keyval_from.key)
        else
            keyval.key.const = keyval_from.key:IsConst()
        end

        if keyval_from.val.Type == "dictionary" then
            keyval.val:CopyConstness(keyval_from.val)
        else
            keyval.val.const = keyval_from.val:IsConst()
        end
    end
    return true
end

function Dictionary:Copy()
    local copy = Dictionary:new({})

    for _, keyval in ipairs(self.data) do
        local k,v = keyval.key, keyval.val

        if k == self then
            k = copy
        else
            k = k:Copy()
        end

        if v == self then
            v = copy
        else
            k = k:Copy()
        end

        copy:Set(k,v)
    end

    copy.meta = self.meta
    copy.volatile = self.volatile

    return copy
end

function Dictionary:Extend(t)
    local copy = self:Copy()

    for _, keyval in ipairs(t.data) do
        if not copy:Get(keyval.key) then
            if keyval.val.self then
                keyval.val = copy
            end
            copy:Set(keyval.key, keyval.val)
        end
    end

    return copy
end

function Dictionary:IsConst()
    for _, v in ipairs(self.data) do
        if v.val ~= self and not v.val:IsConst() then
            return true
        end
    end
    return false
end

function Dictionary:IsFalsy()
    return false
end

function Dictionary:IsTruthy()
    return true
end

function Dictionary:new(data)
    local self = setmetatable({}, self)

    self.data = {}

    if data then
        for _, v in ipairs(data) do
            self:Set(v.key, v.val)
        end
    end

    return self
end

function Dictionary:IsVolatile()
    return self.volatile
end

for k,v in pairs(types.BaseObject) do Dictionary[k] = v end
types.Dictionary = Dictionary

return Dictionary