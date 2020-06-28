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
        return types.Object:new("string", val, true)
    elseif type(val) == "boolean" then
        return types.Object:new("boolean", val, true)
    elseif type(val) == "number" then
        return types.Object:new("number", val, true)
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
        Base.truthy = 0

        function Base:GetTruthy()
            return self.truthy > 0
        end

        function Base:PushTruthy()
            self.truthy = self.truthy + 1
        end
        function Base:PopTruthy()
            self.truthy = self.truthy + 1
        end
    end


    types.BaseObject = Base
end

function types.Initialize()
    types.Set = require("oh.typesystem.set")
    types.Table = require("oh.typesystem.table")
    types.Tuple = require("oh.typesystem.tuple")
    types.Object = require("oh.typesystem.object")
end

return types