local types = require("oh.typesystem.types")

local META = {}
META.Type = "tuple"
META.__index = META

function META:GetSignature()
    local s = {}

    for i,v in ipairs(self.data) do
        s[i] = v:GetSignature()
    end

    return table.concat(s, " ")
end

function META:__tostring()
    local s = {}

    for i,v in ipairs(self.data) do
        s[i] = tostring(v)
    end

    return (self.ElementType and tostring(self.ElementType) or "") .. "⦅" .. table.concat(s, ", ") .. (self.max == math.huge and "..." or (self.max and ("#" .. self.max)) or "") .. "⦆"
end

function META:Merge(tup, dont_extend)
    local src = self.data
    local dst = tup.data

    for i,v in ipairs(dst) do
        if src[i] and src[i].Type ~= "any" then
            if src[i].volatile then
                v = v:Copy()
                v.volatile = true
            end
            src[i] = types.Set({src[i], v})
        else
            local prev = src[i]

            if not dont_extend or prev then
                if not prev or prev.volatile then
                    src[i] = dst[i]:Copy()
                    src[i].volatile = true
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

function META:SetElementType(typ)
    self.ElementType = typ
end

function META:GetMaxLength()
    return self.max or 0
end

function META:GetElements()
    return self.data
end

function META:GetLength()
    return #self.data
end

function META:GetData()
    return self.data
end

function META:Copy()
    local copy = {}
    for i, v in ipairs(self.data) do
        copy[i] = v:Copy()
    end
    return types.Tuple(copy)
end

function META.SubsetOf(A, B)
    if A:GetLength() == 1 then
        return A:Get(1):SubsetOf(B)
    end

    if B.Type == "table" then
        if not B:IsNumericallyIndexed() then
            return types.errors.other(tostring(B) .. " cannot be treated as a tuple because it contains non a numeric index " .. tostring(A))
        end
    end

    if A:GetLength() > B:GetLength() and A:GetLength() > B:GetMaxLength() then
        return types.errors.other(tostring(A) .. " is larger than " .. tostring(B))
    end


    if A.ElementType and A.ElementType.Type == "any" then
        return true
    end

    -- vararg
    if B.max == math.huge then
        local ok, reason = B:Get(1):SubsetOf(A)
        if not ok then
            return types.errors.subset(B:Get(1), A, reason)
        end
        return true
    end

    for i = 1, A:GetLength() do
        local a = A:Get(i)
        local b = B:Get(i)

        if not b then
            return types.errors.missing(B, i)
        end

        local ok, reason = a:SubsetOf(b)

        if not ok then
            return types.errors.subset(a, b, reason)
        end
    end

    return true
end

function META:Get(key)
    if type(key) == "number" then
        return self.data[key]
    end

    if key.Type == "number" or key.Type == "string" and key:IsLiteral() then
        key = key.data
    end

    return self.data[key]
end

function META:Set(key, val)
    self.data[key] =  val
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

function META:IsVolatile()
    for i,v in ipairs(self.data) do
        if not v:IsVolatile() then
            return false
        end
    end
    return true
end


function META:IsTruthy()
    return true
end

function META:IsFalsy()
    return false
end

function META:Initialize(data)
    self.data = data or {}

    for _,v in ipairs(self.data) do
        if not types.IsTypeObject(v) then
            for k,v in pairs(v) do print(k,v) end
            error(tostring(v) .. " is not a type object")
        end
    end

    return self
end

return types.RegisterType(META)