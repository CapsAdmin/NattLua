local types = require("oh.typesystem.types")

local Dictionary = {}
Dictionary.Type = "dictionary"
Dictionary.__index = Dictionary

function Dictionary:GetSignature()
    if self.supress then
        return "*self*"
    end
    self.supress = true

    if not self.data[1] then
        return "{}"
    end

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
    if not self.data[1] then
        return "{}"
    end

    if self.supress then
        return "*self*"
    end
    self.supress = true

    local s = {}

    level = level + 1
    for i, keyval in ipairs(self.data) do
        s[i] = ("\t"):rep(level) .. tostring(keyval.key) .. " = " .. tostring(keyval.val)
    end
    level = level - 1

    self.supress = nil

    table.sort(s, function(a, b) return a > b end)

    return "{\n" .. table.concat(s, ",\n") .. "\n" .. ("\t"):rep(level) .. "}"
end

function Dictionary:__tostring()
    return (self:Serialize():gsub("%s+", " "))
end

function Dictionary:GetLength()
    return #self.data
end

function Dictionary:SupersetOf(sub)
    if self == sub then
        return true
    end

    if sub.Type == "tuple" then
        if sub:GetLength() > 0 then
            for i, keyval in ipairs(self.data) do
                if keyval.key.type == "number" then
                    if not sub:Get(i) or not sub:Get(i):SupersetOf(keyval.val) then
                        return false
                    end
                end
            end
        else
            local count = 0
            for i, keyval in ipairs(self.data) do
                if keyval.key.data ~= i then
                    return false
                end

                count = count + 1
            end
            if count ~= sub:GetMaxLength() then
                return false
            end
        end

        return true
    end


    for _, keyval in ipairs(self.data) do
        local val = sub:Get(keyval.key, true)

        if not val then
            return false
        end

        if not keyval.val:SupersetOf(val) then
            return false
        end
    end


    return true
end

function Dictionary:Lock(b)
    self.locked = b
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

function Dictionary:Set(key, val, env)
    key = types.Cast(key)
    val = types.Cast(val)

    if key.type == "nil" then
        return false, "key is nil"
    end

    local data = self.data

    if val == nil or val.type == "nil" then
        for i, keyval in ipairs(data) do
            if key:SupersetOf(keyval.key) then
                table.remove(data, i)
                return true
            end
        end
        return false
    end

    for _, keyval in ipairs(data) do
        if key:SupersetOf(keyval.key) and (env == "typesystem" or val:SupersetOf(keyval.val)) then
            if not self.locked then
                keyval.val = val
            end
            return true
        end
    end

    if not self.locked then
        table.insert(data, {key = key, val = val})
        return true
    end

    local obj = self

    local expected_keys = {}
    local expected_values = {}
    for _, keyval in ipairs(obj.data) do
        if not key:SupersetOf(keyval.key) then
            table.insert(expected_keys, tostring(keyval.key))
        elseif not val:SupersetOf(keyval.val) then
            table.insert(expected_values, tostring(keyval.val))
        end
    end

    if #expected_values > 0 then
        return false, "invalid value " .. tostring(val.type or val) .. " expected " .. table.concat(expected_values, " | ")
    elseif #expected_keys > 0 then
        return false, "invalid key " .. tostring(key.type or key) .. " expected " .. table.concat(expected_keys, " | ")
    end

    return false, "invalid key " .. tostring(key.type or key)
end

function Dictionary:Get(key, env)
    key = types.Cast(key)

    local keyval = self:GetKeyVal(key, env)

    if not keyval and self.meta then
        local index = self.meta:Get("__index")
        if index.Type == "dictionary" then
            return index:Get(key)
        end
    end

    if keyval then
        return keyval.val
    end
end

function Dictionary:GetKeyVal(key, env)
    for _, keyval in ipairs(env == "typesystem" and self.structure or self.data) do
        if key:SupersetOf(keyval.key) then
            return keyval
        end
    end
end

function Dictionary:Copy()
    local copy = Dictionary:new({})

    for _, keyval in ipairs(self.data) do
        copy:Set(keyval.key, keyval.val)
    end

    return copy
end

function Dictionary:Extend(t)
    local copy = self:Copy()

    for _, keyval in ipairs(t.data) do
        if not copy:Get(keyval.key) then
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

function Dictionary:PrefixOperator(op, val)
    if op == "#" then
        if self.meta and self.meta:Get("__len") then
            error("NYI")
        end

        return types.Create("number", #self.data, true)
    end

    return false, "NYI " .. op
end

function Dictionary:new(data)
    local self = setmetatable({}, self)

    self.data = {}
    self.structure = {}

    if data then
        for _, v in ipairs(data) do
            self:Set(v.key, v.val)
        end
    end

    return self
end

for k,v in pairs(types.BaseObject) do Dictionary[k] = v end
types.Dictionary = Dictionary

return Dictionary