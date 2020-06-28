local types = require("oh.typesystem.types")
local syntax = require("oh.lua.syntax")
local bit = not _G.bit and require("bit32") or _G.bit

local Function = {}
Function.Type = "function"
Function.__index = Function

function Function:GetSignature()
    return "function" .. "-"..types.GetSignature(self.data)
end

function Function:Get(key)
    local val = type(self.data) == "table" and self.data:Get(key)

    if not val and self.meta then
        local index = self.meta:Get("__index")
        if index.Type == "table" then
            return index:Get(key)
        end
    end

    return val
end

function Function:Get(key)
    return false, "cannot " .. tostring(self) .. "[" .. tostring(key) .."]"
    --return self.data
end

function Function:Set(key, val)
    return false, "cannot " .. tostring(self) .. "[" .. tostring(key) .."] = " .. tostring(val)
    --self.data = val
end

function Function:GetArguments()
    return self.data.arg
end

function Function:GetReturnTypes()
    return self.data.ret
end

function Function:Copy()
    local data = {ret = self.data.ret:Copy(), arg = self.data.arg:Copy()}

    local copy = Function:new(data, self.literal)
    copy.volatile = self.volatile
    return copy
end

function Function.SubsetOf(A, B)
    if A.Type == "any" or A.volatile then return true end
    if B.Type == "any" or B.volatile then return true end

    if B.Type == "tuple" and B:GetLength() == 1 then B = B:Get(1) end

    if B.Type == "function" then
        local ok, reason = A:GetArguments():SubsetOf(B:GetArguments())
        if not ok then
            return false, "function arguments don't match because " .. reason
        end

        local ok, reason = A:GetReturnTypes():SubsetOf(B:GetReturnTypes())
        if not ok then
            return false, "return types don't match because " .. reason
        end

        return true
    elseif B.Type == "set" then
        return types.Set:new({A}):SubsetOf(B)
    end

    return false, "NYI " .. tostring(B)
end

function Function:__tostring()
    --return "「"..self.uid .. " 〉" .. self:GetSignature() .. "」"
    return "function" .. tostring(self.data.arg) .. ": " .. tostring(self.data.ret)
end

function Function:Serialize()
    return self:__tostring()
end

function Function:IsVolatile()
    return self.volatile == true
end

function Function:IsFalsy()
    return false
end

function Function:IsTruthy()
    return true
end

function Function:RemoveNonTruthy()
    return self
end

local uid = 0

function Function:new(data)
    local self = setmetatable({}, self)

    uid = uid + 1

    self.uid = uid
    self.data = data

    return self
end

types.RegisterType(Function)

return Function