local types = {}

types.errors = {
    subset = function(a, b, reason)
        local msg = tostring(a) .. " is not a subset of " .. tostring(b)

        if reason then
            msg = msg .. " because " .. reason
        end

        return false, msg
    end,
    missing = function(a, b)
        local msg = tostring(a) .. " does not contain " .. tostring(b)
        return false, msg
    end,
    other = function(msg)
        return false, msg
    end,
}

function types.Cast(val)
    if type(val) == "string" then
        return types.String(val):MakeLiteral(true)
    elseif type(val) == "boolean" then
        return types.Symbol(val)
    elseif type(val) == "number" then
        return types.Number(val):MakeLiteral(true)
    end
    return val
end

function types.IsPrimitiveType(val)
    return val == "string" or
    val == "number" or
    val == "boolean" or
    val == "true" or
    val == "false" or
    val == "nil"
end

function types.IsTypeObject(obj)
    return type(obj) == "table" and obj.Type ~= nil
end

do
    local Base = {}

    function Base:IsUncertain()
        return self:IsTruthy() and self:IsFalsy()
    end

    function Base:SetSource(node, source, l,r)
        self.source = source
        self.node = node
        self.source_left = l
        self.source_right = r
        return self
    end 

    function Base:GetSignature()
        error("NYI")
    end

    function Base:GetSignature()
        error("NYI")
    end

    Base.literal = false

    function Base:MakeExplicitNotLiteral(b)
        self.explicit_not_literal = b
        return self
    end


    do
        local ref = 0

        function Base:MakeUnique(b)
            if b then
                self.unique_id = ref
                ref = ref + 1
            else 
                self.unique_id = nil
            end
            return self
        end

        function Base:IsUnique()
            return self.unique_id ~= nil
        end

        function Base:GetUniqueID()
            return self.unique_id
        end

        function Base:DisableUniqueness()
            self.disabled_unique_id = self.unique_id
            self.unique_id = nil
        end

        function Base:EnableUniqueness()
            self.unique_id = self.disabled_unique_id
        end

        function types.IsSameUniqueType(a, b)
            if a.unique_id and not b.unique_id then
                return types.errors.other(tostring(a) .. "is a unique type")
            end

            if b.unique_id and not a.unique_id then
                return types.errors.other(tostring(b) .. "is a unique type")
            end

            if a.unique_id ~= b.unique_id then
                return types.errors.other(tostring(a) .. "is not the same unique type as " .. tostring(a))
            end

            return true
        end
    end

    function Base:MakeLiteral(b)
        self.literal = b
        return self
    end

    function Base:IsLiteral()
        return self.literal
    end

    function Base:Seal()
        self.contract = self:Copy()
    end

    function Base:CopyLiteralness(obj)
        self:MakeLiteral(obj:IsLiteral())    
    end

    function Base:Call()
        return types.errors.other("type " .. self.Type .. ": " .. tostring(self) .. " cannot be called")        
    end

    function Base:SetReferenceId(ref)
        self.reference_id = ref
        return self
    end

    types.BaseObject = Base
end

local uid = 0
function types.RegisterType(meta)
    for k, v in pairs(types.BaseObject) do
        if not meta[k] then
            meta[k] = v
        end
    end

    return function(data)
        local self = setmetatable({}, meta)
        self.data = data
        self.uid = uid
        uid = uid + 1
        
        if self.Initialize then
            local ok, err = self:Initialize(data)
            if not ok then
                return ok, err
            end
        end
    
        return self
    end
end

function types.Initialize()
    types.Set = require("oh.typesystem.set")
    types.Table = require("oh.typesystem.table")
    types.List = require("oh.typesystem.list")
    types.Tuple = require("oh.typesystem.tuple")
    types.Number = require("oh.typesystem.number")
    types.Function = require("oh.typesystem.function")
    types.String = require("oh.typesystem.string")
    types.Any = require("oh.typesystem.any")
    types.Symbol = require("oh.typesystem.symbol")
    types.Never = require("oh.typesystem.never")

    types.Nil = types.Symbol()
    types.True = types.Symbol(true)
    types.False = types.Symbol(false)
    types.Boolean = types.Set({types.True, types.False}):MakeExplicitNotLiteral(true)
end

return types