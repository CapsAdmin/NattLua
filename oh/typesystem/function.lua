local types = require("oh.typesystem.types")
local syntax = require("oh.lua.syntax")
local bit = not _G.bit and require("bit32") or _G.bit

local META = {}
META.Type = "function"
META.__index = META

function META:GetSignature()
    if self.suppress then
        return "*self*"
    end

    self.suppress = true
    local s = "function" .. "-"..self:GetArguments():GetSignature() .. ":" .. self:GetReturnTypes():GetSignature()
    self.suppress = false

    return s
end

function META:__tostring()
    if self.suppress then
        return "*self*"
    end

    self.suppress = true
    local s = "function" .. tostring(self:GetArguments()) .. ": " .. tostring(self:GetReturnTypes())
    self.suppress = false

    return s
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
    copy.data.ret = self:GetReturnTypes():Copy(map)
    copy.data.arg = self:GetArguments():Copy(map)
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
        if not ok and ((not B.called and not B.explicit_return) or (not A.called and not A.explicit_return)) then
            return true
        end

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

function META:CheckArguments(arguments)
    local A = arguments -- incoming
    local B = self:GetArguments() -- the contract
    -- A should be a subset of B

    if A:GetSignature() == B:GetSignature() then
        return true
    end

    if A:GetLength() == math.huge and B:GetLength() == math.huge then
   --     local ok, err = A.Remainder:SubsetOf(B.Remainder)
     --   if not ok then
       --     return ok, err
        --end

        for i = 1, math.max(A:GetMinimumLength(), B:GetMinimumLength()) do
            local a = A:Get(i)
            local b = B:Get(i)

            local ok, err = a:SubsetOf(b)
            if not ok then
                return ok, err
            end
        end

        return true
    end

    for i = 1, math.min(A:GetLength(), B:GetLength()) do
        local a = A:Get(i)
        local b = B:Get(i)

        if not b then
            break
        end

        if b.Type == "tuple" then
            b = b:Get(1)
            if not b then
                break
            end
        end
        
        a = a or types.Nil
        b = b or types.Nil

        local ok, reason = a:SubsetOf(b)

        if not ok then
            if b.node then
                return types.errors.other("function argument #"..i.." '" .. tostring(b) .. "': " .. reason)
            else
                return types.errors.other("argument #" .. i .. " - " .. reason)
            end
        end
    end

    return true
end

return types.RegisterType(META)