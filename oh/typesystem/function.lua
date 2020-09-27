local types = require("oh.typesystem.types")
local syntax = require("oh.lua.syntax")
local bit = not _G.bit and require("bit32") or _G.bit

local META = {}
META.Type = "function"
META.__index = META

function META:GetSignature()
    return "function" .. "-"..self:GetArguments():GetSignature() .. ":" .. self:GetReturnTypes():GetSignature()
end

function META:__tostring()
    return "function" .. tostring(self:GetArguments()) .. ": " .. tostring(self:GetReturnTypes())
end

function META:Get(key)
    return types.errors.other("cannot " .. tostring(self) .. "[" .. tostring(key) .."]")
    --return self.data
end

function META:Set(key, val)
    return types.errors.other("cannot " .. tostring(self) .. "[" .. tostring(key) .."] = " .. tostring(val))
    --self.data = val
end

function META:GetArguments()
    return self.data.arg
end

function META:GetReturnTypes()
    return self.data.ret
end

function META:Copy(map)
    map = map or {}

    local copy = types.Function({})
    map[self] = map[self] or copy
    copy.data.ret = self.data.ret:Copy(map)
    copy.data.arg = self.data.arg:Copy(map)
    copy:MakeLiteral(self:IsLiteral())

    copy.node = self.node
    copy.function_body_node = self.function_body_node

    return copy
end

function META.SubsetOf(A, B)
    if A.Type == "any" then return true end
    if B.Type == "any" then return true end
    if B.Type == "tuple" and B:GetLength() == 1 then B = B:Get(1) end

    if B.Type == "function" then
        local ok, reason = A:GetArguments():SubsetOf(B:GetArguments())
        if not ok then
            return types.errors.other("function arguments don't match because " .. reason)
        end

        local ok, reason = A:GetReturnTypes():SubsetOf(B:GetReturnTypes())
        if not ok then
            return types.errors.other("return types don't match because " .. reason)
        end

        return true
    elseif B.Type == "set" then
        return types.Set({A}):SubsetOf(B)
    end

    return types.errors.other("NYI " .. tostring(B))
end

function META:IsFalsy()
    return false
end

function META:IsTruthy()
    return true
end

return types.RegisterType(META)