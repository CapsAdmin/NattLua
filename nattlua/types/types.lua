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
    elseif type(val) == "table" and val.kind == "value" then
        return types.String(val.value.value):MakeLiteral(true)
    end

    if not types.IsTypeObject(val) then
        error("cannot cast" .. tostring(val), 2)
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
    local compare_condition

    local function cmp(a, b, context)
        if not context[a] then
            context[a] = {}
            context[a][b] = types.FindInType(a, b, context)
        end
        return context[a][b]
    end

    function types.FindInType(a, b, context)
        context = context or {}

        if not a then return false end
        
        if a == b then return true end
            
        if a.upvalue and b.upvalue then
            if a.upvalue == b.upvalue then
                return true
            end
        end

        if a.type_checked then
            return cmp(a.type_checked, b, context)
        end

        if a.source_left then
            return cmp(a.source_left, b, context)
        end

        if a.source_right then
            return cmp(a.source_right, b, context)
        end

        if a.source then
            return cmp(a.source, b, context)
        end

        return false
    end
end

do
    local Base = {}

    function Base:IsUncertain()
        return self:IsTruthy() and self:IsFalsy()
    end

    function Base:CopyInternalsFrom(obj)
        self.name = obj.name
        self.node = obj.node
        self.node_label = obj.node_label
        self.source = obj.source
        self.source_left = obj.source_left
        self.source_right = obj.source_right
        self.explicit_not_literal = obj.explicit_not_literal
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
        self.contract = self.contract or self:Copy()
    end

    function Base:CopyLiteralness(obj)
        self:MakeLiteral(obj:IsLiteral())    
    end

    function Base:Call(...)
        return types.errors.other("type " .. self.Type .. ": " .. tostring(self) .. " cannot be called")        
    end

    function Base:SetReferenceId(ref)
        self.reference_id = ref
        return self
    end

    function Base:Set(key, val)
        return types.errors.other("undefined set: " .. tostring(self) .. "[" .. tostring(key) .. "] = " .. tostring(val) .. " on type " .. self.Type)
    end

    function Base:Get(key)
        return types.errors.other("undefined get: " .. tostring(self) .. "[" .. tostring(key) .. "]" .. " on type " .. self.Type)
    end

    function Base:AddReason(reason, ...)
        table.insert(self.reasons, {
            msg = reason,
            data = {...}
        })
        return self
    end

    function Base:GetReasonForExistance()
        local str = ""
        
        for k,v in ipairs(self.reasons) do
            str = str .. v.msg .. "\n"
        end

        return str
    end

    function Base:SetParent(parent)
        if parent then
            if parent ~= self then
                self.parent = parent
            end
        else
            self.parent = nil
        end
    end

    function Base:GetRoot()
        local parent = self
        while true do
            if not parent.parent then
                break
            end
            parent = parent.parent
        end
        return parent
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
        self.reasons = {}
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
    types.Union = require("nattlua.types.union")
    types.Table = require("nattlua.types.table")
    types.List = require("nattlua.types.list")
    types.Tuple = require("nattlua.types.tuple")
    types.Number = require("nattlua.types.number")
    types.Function = require("nattlua.types.function")
    types.String = require("nattlua.types.string")
    types.Any = require("nattlua.types.any")
    types.Symbol = require("nattlua.types.symbol")
    types.Never = require("nattlua.types.never")
    types.Error = require("nattlua.types.error")

    types.Nil = types.Symbol()
    types.True = types.Symbol(true)
    types.False = types.Symbol(false)
    types.Boolean = types.Union({types.True, types.False}):MakeExplicitNotLiteral(true)
end

function types.View(obj)
    return setmetatable({obj = obj, GetType = function() return obj end}, {
        __index = function(_, key) return types.View(assert(obj:Get(key))) end,
        __newindex = function(_, key, val) assert(obj:Set(key, val)) end,
        __call = function(_, ...) return types.View(assert(obj:Call(...))) end,
    })
end

return types