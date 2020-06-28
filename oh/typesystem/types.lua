local syntax = require("oh.lua.syntax")

local types = {}



--[[
    this keeps confusing me

    subset:
        A subsetof B
        A within B
        A inside B
        A compatible with B
        A child of B

    superset:
        A parent of B
        A supersetof B
        A covers B
        A contains B
        A has B
        A owns B
        A entails B
]]


types.errors = {
    subset = function(a, b, reason)
        local msg = tostring(a) .. " is not a subset of " .. tostring(b)

        if reason then
            msg = msg .. " because " .. reason
        end

        return false, msg
    end,
    missing = function(a, b)
        return false, tostring(a) .. " does not contain " .. tostring(b)
    end
}

function types.Cast(val)
    if type(val) == "string" then
        return types.String:new(val):MakeLiteral(true)
    elseif type(val) == "boolean" then
        return types.Symbol:new(val)
    elseif type(val) == "number" then
        return types.Number:new(val):MakeLiteral(true)
    end
    return val
end

function types.GetSignature(obj)
    if type(obj) == "table" and obj.GetSignature then
        return obj:GetSignature()
    end

    return tostring(obj)
end

function types.IsPrimitiveType(val)
    return val == "string" or
    val == "number" or
    val == "boolean" or
    val == "true" or
    val == "false"
end

function types.IsTypeObject(obj)
    return type(obj) == "table" and obj.Type ~= nil
end

do
    local Base = {}

    do
        Base.truthy_level = 0

        function Base:GetTruthy()
            return self.truthy_level > 0
        end

        function Base:PushTruthy()
            self.truthy_level = self.truthy_level + 1
        end
        function Base:PopTruthy()
            self.truthy_level = self.truthy_level - 1
        end
    end

    function Base:GetSignature()
        error("NYI")
    end

    function Base:Serialize()
        error("NYI")
    end

    Base.literal = false

    function Base:MakeLiteral(b)
        self.literal = b
        return self
    end

    function Base:IsLiteral()
        return self.literal
    end

    types.BaseObject = Base
end

function types.RegisterType(meta)
    for k, v in pairs(types.BaseObject) do
        if not meta[k] then
            meta[k] = v
        end
    end
end

function types.Initialize()
    types.Set = require("oh.typesystem.set")
    types.Table = require("oh.typesystem.table")
    types.Tuple = require("oh.typesystem.tuple")
    types.Number = require("oh.typesystem.number")
    types.Function = require("oh.typesystem.function")
    types.String = require("oh.typesystem.string")
    types.Any = require("oh.typesystem.any")
    types.Symbol = require("oh.typesystem.symbol")

    types.Nil = types.Symbol:new()
    types.True = types.Symbol:new(true)
    types.False = types.Symbol:new(false)
    types.AnyType = types.Any:new()
    types.Boolean = types.Set:new({types.True, types.False})
    types.NumberType = types.Number:new()
    types.StringType = types.String:new()
end

return types