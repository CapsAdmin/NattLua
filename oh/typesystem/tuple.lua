local types = require("oh.typesystem.types")

local Tuple = {}
Tuple.Type = "tuple"
Tuple.__index = Tuple

function Tuple:GetSignature()
    local s = {}

    for i,v in ipairs(self.data) do
        s[i] = types.GetSignature(v)
    end

    return table.concat(s, " ")
end

function Tuple:PrefixOperator(op, env)
    return self.data[1]:PrefixOperator(op, env)
end

function Tuple:Call(arguments)
    local out = types.Set:new()

    for _, obj in ipairs(self.data) do
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

function Tuple:Merge(tup, dont_extend)
    local src = self.data
    local dst = tup.data

    for i,v in ipairs(dst) do
        if src[i] and src[i].type ~= "any" then
            if src[i].volatile then
                v = v:Copy()
                v.volatile = true
            end
            src[i] = types.Set:new({src[i], v})
        else
            local prev = src[i]

            if not dont_extend or prev then
                if not prev or prev.volatile then
                    src[i] = dst[i]:Copy()
                end

                if prev and prev.volatile then
                    src[i] = src[i]:Copy()
                    src[i].volatile = true
                end
            end
        end
    end

    return self
end

function Tuple:GetMaxLength()
    return self.max or 0
end

function Tuple:GetLength()
    return #self.data
end

function Tuple:GetData()
    return self.data
end

function Tuple:Copy()
    local copy = {}
    for i, v in ipairs(self.data) do
        copy[i] = v:Copy()
    end
    return Tuple:new(copy)
end

function Tuple:SupersetOf(sub)
    if self:GetLength() == 1 then
        return self.data[1]:SupersetOf(sub)
    end

    if sub.Type == "dictionary" then
        local hm = {}

        for i,v in ipairs(sub.data) do
            if v.key.type == "number" then
                hm[v.key.data] = v.val.data
            end
        end

        if #hm ~= #sub.data then
            return false
        end
    end

    for i = 1, sub:GetLength() do
        local a = self:Get(i)
        local b = sub:Get(i)

        -- vararg
        if a and a.max == math.huge and a:Get(1):SupersetOf(b) then
            return true
        end

        if not a and i <= self:GetMaxLength() then
            print("LOL")
        elseif b.type ~= "any" and (not a or not a:SupersetOf(b)) then
            return false
        end
    end

    return true
end

function Tuple:Get(key)
    if type(key) == "number" then
        return self.data[key]
    end

    if key.Type == "object" then
        if key:IsType("number") then
            key = key.data
        elseif key:IsType("string") then
            key = key.data
        end
    end

    return self.data[key]
end

function Tuple:Set(key, val)
    self.data[key] =  val
    return true
end

function Tuple:__tostring()
    local s = {}

    for i,v in ipairs(self.data) do
        s[i] = tostring(v)
    end

    return "(" .. table.concat(s, ", ") .. (self.max == math.huge and "..." or (self.max and ("#" .. self.max)) or "") .. ")"
end

function Tuple:Serialize()
    return self:__tostring()
end

function Tuple:IsConst()
    for i,v in ipairs(self.data) do
        if not v:IsConst() then
            return false
        end
    end
    return true
end

function Tuple:IsTruthy()
    return true
end

function Tuple:IsFalsy()
    return false
end

function Tuple:new(tbl)
    local self = setmetatable({}, self)
    self.data = tbl or {}

    for i,v in ipairs(self.data) do
        if not types.IsTypeObject(v) then
            error(tostring(v) .. " is not a type object")
        end
    end

    return self
end

for k,v in pairs(types.BaseObject) do Tuple[k] = v end
types.Tuple = Tuple

return Tuple