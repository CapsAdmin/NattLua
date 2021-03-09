local types = require("nattlua.types.types")
local syntax = require("nattlua.syntax.syntax")
local type_errors = require("nattlua.types.error_messages")

local META = {}
META.Type = "function"
require("nattlua.types.base")(META)

function META:__call(...)
    if self:GetData().lua_function then
        return self:GetData().lua_function(...)
    end
end

function META.Equal(a, b)
    return 
        a.Type == b.Type and
        a:GetArguments():Equal(b:GetArguments()) and 
        a:GetReturnTypes():Equal(b:GetReturnTypes())
end

function META:__tostring()
    return "function" .. tostring(self:GetArguments()) .. ": " .. tostring(self:GetReturnTypes())
end

function META:GetLuaType()
    return "function"
end

function META:GetArguments()
    return self:GetData().arg or types.Tuple({})
end

function META:GetReturnTypes()
    return self:GetData().ret or types.Tuple({})
end

function META:HasExplicitReturnTypes()
    return self.explicit_return_set
end

function META:SetReturnTypes(tup)
    self:GetData().ret = tup
    self.explicit_return_set = tup
    self.called = nil
end

function META:SetArguments(tup)
    self:GetData().arg = tup
    self.called = nil
end

function META:Copy(map)
    map = map or {}

    local copy = types.Function({arg = types.Tuple({}), ret = types.Tuple({})})
    map[self] = map[self] or copy
    copy:GetData().ret = self:GetReturnTypes():Copy(map)
    copy:GetData().arg = self:GetArguments():Copy(map)
    copy:SetLiteral(self:IsLiteral())

    copy:CopyInternalsFrom(self)
    copy.function_body_node = self.function_body_node

    return copy
end

function META:Initialize(data)
    if not data.ret or not data.arg then
        error("function initialized without ret or arg", 2)
    end
    return self
end

function META.IsSubsetOf(A, B)
    if A.Type == "any" then return true end
    if B.Type == "any" then return true end
    if B.Type == "tuple" and B:GetLength() == 1 then B = B:Get(1) end

    if B.Type == "function" then
        local ok, reason = A:GetArguments():IsSubsetOf(B:GetArguments())
        
        if not ok then
            return type_errors.subset(A:GetArguments(), B:GetArguments(), reason)
        end

        local ok, reason = A:GetReturnTypes():IsSubsetOf(B:GetReturnTypes())
        if not ok and ((not B.called and not B.explicit_return) or (not A.called and not A.explicit_return)) then
            return true
        end

        if not ok then
            return type_errors.subset(A:GetReturnTypes(), B:GetReturnTypes(), reason)
        end

        return true
    elseif B.Type == "union" then
        return types.Union({A}):IsSubsetOf(B)
    end

    return type_errors.type_mismatch(A, B)
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

    if A:Equal(B) then
        return true
    end

    if A:GetLength() == math.huge and B:GetLength() == math.huge then
        for i = 1, math.max(A:GetMinimumLength(), B:GetMinimumLength()) do
            local a = A:Get(i)
            local b = B:Get(i)

            local ok, err = a:IsSubsetOf(b)
            if not ok then
                return type_errors.subset(a, b, err)
            end
        end

        return true
    end

    for i = 1, math.max(A:GetMinimumLength(), B:GetMinimumLength()) do
        local a, a_err = A:Get(i)
        local b, b_err = B:Get(i)
        
        if not a then
            if b and b.Type == "any" then
                a = types.Any()
            else
                return a, a_err
            end
        end

        if not b then
            return b, b_err
        end

        if b.Type == "tuple" then
            b = b:Get(1)
            if not b then
                break
            end
        end
        
        a = a or types.Nil()
        b = b or types.Nil()

        local ok, reason = a:IsSubsetOf(b)

        if not ok then
            if b:GetNode() then
                return type_errors.subset(a, b, {"function argument #", i, " '", b, "': ", reason})
            else
                return type_errors.subset(a, b, {"argument #", i, " - ", reason})
            end
        end
    end

    return true
end

return META