local types = require("nattlua.types.types")

local META = {}
META.Type = "tuple"
META.__index = META

function META:GetSignature()
    if self.suppress then
        return "*"
    end

    self.suppress = true

    local s = {"T"}

    for i,v in ipairs(self.data) do
        s[i+1] = v:GetSignature()
    end

    if self.Remainder then
        table.insert(s, self.Remainder:GetSignature())
    end

    if self.Repeat then
        table.insert(s, "x")
        table.insert(s, tostring(self.Repeat))
    end

    self.suppress = false

    return table.concat(s)
end

function META:__tostring()
    if self.suppress then
        return "*self*"
    end

    self.suppress = true

    local s = {}

    for i,v in ipairs(self.data) do
        s[i] = tostring(v)
    end

    if self.Remainder then
        table.insert(s, tostring(self.Remainder))
    end

    local s = "⦗" .. table.concat(s, ", ") .. "⦘"

    if self.Repeat then
        s = s .. "×" .. tostring(self.Repeat)
    end

    self.suppress = false

    return s
end

function META:Merge(tup)

    if tup.Type == "union" then
        for _, obj in ipairs(tup:GetData()) do
            self:Merge(obj)
        end
        return self
    end

    local src = self.data

    if tup:GetMinimumLength() > 512 then
        error("tuple overflow")
    end

    for i = 1, tup:GetMinimumLength() do
        local a = self:Get(i)
        local b = tup:Get(i)
        if a then
            src[i] = types.Union({a, b})
        else
            src[i] = b:Copy()
        end
    end

    self.Remainder = tup.Remainder or self.Remainder
    self.Repeat = tup.Repeat or self.Repeat

    return self
end

function META:GetTypes()
    return self.data
end

function META:SetReferenceId(id)

    for i = 1, #self:GetTypes() do
        self:Get(i):SetReferenceId(id)
    end

    return self
end

function META:GetData()
    return self.data
end

function META:Copy(map)
    map = map or {}

    local copy = types.Tuple({})
    map[self] = map[self] or copy
    
    for i, v in ipairs(self.data) do
        v = map[v] or v:Copy(map)
        map[v] = map[v] or v
        copy:Set(i, v)
    end

    copy:CopyInternalsFrom(self)
    copy.Remainder = self.Remainder
    copy.Repeat = self.Repeat

    return copy
end

function META.IsSubsetOf(A, B)
    if A == B then
        return true
    end

    if A.suppress then
        return true
    end
    
    if A.Remainder and A:Get(1).Type == "any" and #A:GetData() == 0 then
        return true
    end

    if B.Type == "union" then
        local errors = {}
        for _, tup in ipairs(B:GetData()) do
            A.suppress = true
            local ok, reason = A:IsSubsetOf(tup)
            A.suppress = false
            if ok then
                return true
            else
                table.insert(errors, reason)
            end
        end
        return types.errors.subset(A, B, table.concat(errors, "\n"))
    end

    if A:Get(1) and A:Get(1).Type == "any" and B.Type == "tuple" and B:GetLength() == 0 then
        return true
    end

    if B.Type == "any" then
        return true
    end

    if B.Type == "table" then
        if not B:IsNumericallyIndexed() then
            return types.errors.numerically_indexed(B)
        end
    end

    if B.Type ~= "tuple" then
        return types.errors.type_mismatch(A, B)
    end

    for i = 1, math.max(A:GetMinimumLength(), B:GetMinimumLength()) do
        local a, err = A:Get(i)
        if not a then
            return types.errors.subset(A, B, err)
        end

        local b, err = B:Get(i)

        if not b and a.Type == "any" then
            break
        end

        if not b then
            return types.errors.missing(B, i, err)
        end

        A.suppress = true
        local ok, reason = a:IsSubsetOf(b)
        A.suppress = false

        if not ok then
            return types.errors.subset(a, b, reason)
        end
    end

    if A:GetMinimumLength() < B:GetMinimumLength() then
        return false, "length differs"
    end

    return true
end

function META:Get(key)
    local real_key = key
    assert(type(key) == "number", "key must be a number, got " .. tostring(type(key)))

    local val = self.data[key]

    if not val and self.Repeat and key <= (#self.data * self.Repeat) then
        return self.data[((key-1) % #self.data) + 1]
    end

    if not val and self.Remainder then
        return self.Remainder:Get(key - #self.data)
    end

    if not val and self.data[#self.data] and (self.data[#self.data].Repeat or self.data[#self.data].Remainder) then
        return self.data[#self.data]:Get(key)
    end

    if not val then
        return types.errors.other("index " .. key .. " does not exist")
    end

    return val
end

function META:Set(key, val)
    self.data[key] =  val
    if key > 32 then
        error("tuple too long", 2)
    end
    return true
end


function META:IsConst()
    for _, obj in ipairs(self.data) do
        if not obj:IsConst() then
            return false
        end
    end
    return true
end

function META:IsEmpty()
    return self:GetLength() == 0
end

function META:SetLength()

end

function META:IsTruthy()
    local obj = self:Get(1)
    if obj then
        return obj:IsTruthy()
    end
    return false
end

function META:IsFalsy()
    local obj = self:Get(1)
    if obj then
        return obj:IsFalsy()
    end
    return false
end

function META:GetLength()
    if self.Remainder then
        return #self.data + self.Remainder:GetLength()
    end
    
    if self.Repeat then
        return #self.data * self.Repeat
    end

    return #self.data
end

function META:GetMinimumLength()
    local len = #self.data
    local found_nil = false

    for i = #self.data, 1, -1 do
        local obj = self.data[i]
        
        if obj.Type == "union" and obj:HasNil() then
            found_nil = true
        elseif found_nil then
            len = i
            break
        end
    end

    return len
end

function META:GetSafeLength(arguments)
    local len = self:GetLength()

    if len == math.huge or arguments:GetLength() == math.huge then
        return math.max(self:GetMinimumLength(), arguments:GetMinimumLength())
    end

    return len
end

function META:AddRemainder(obj)
    self.Remainder = obj
    return self
end

function META:SetRepeat(amt)
    self.Repeat = amt
    return self
end

function META:Unpack(length)
    length = length or self:GetLength()
    length = math.min(length, self:GetLength())

    assert(length ~= math.huge, "length must be finite")

    local out = {}

    local i = 1
    for _ = 1, length do
        out[i] = self:Get(i)
        if out[i] and out[i].Type == "tuple" then
            if i == length then
                for _, v in ipairs({out[i]:Unpack(out[i]:GetMinimumLength())}) do
                    out[i] = v
                    i = i + 1
                end
            else
                out[i] = out[i]:Get(1)
            end
        end
        i = i + 1
    end

    return table.unpack(out)
end

function META:Slice(start, stop)
    -- NOT ACCURATE YET

    start = start or 1
    stop = stop or #self.data

    local copy = self:Copy()
    copy.data = {}
    for i = start, stop do
        table.insert(copy.data, self.data[i])
    end
    return copy
end

function META:Initialize(data)
    self.data = {}
    data = data or {}
    
    for i, v in ipairs(data) do
        if not types.IsTypeObject(v) then
            for k,v in pairs(v) do print(k,v) end
            error(tostring(v) .. " is not a type object")
        end

        if i == #data and v.Type == "tuple" and not v.Remainder then
            self:AddRemainder(v)
        else
            self:Set(i, v)
        end
    end


    return true
end


return types.RegisterType(META)