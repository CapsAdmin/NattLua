local types = {}

types.errors = {
    subset = function(a, b, reason)
        local msg = tostring(a) .. " is not a subset of " .. tostring(b)

        if reason then
            msg = msg .. " because " .. reason
        end

        return false, msg
    end,
    missing = function(a, b, reason)
        local msg = tostring(a) .. " does not contain " .. tostring(b) .. " because " .. reason
        return false, msg
    end,
    other = function(msg)
        return false, msg
    end,
    type_mismatch = function(a, b)
        return false, tostring(a) .. " is not the same type as " .. tostring(b)
    end,
    value_mismatch = function(a, b)
        return false, tostring(a) .. " is not the same value as " .. tostring(b)
    end,
    operation = function(op, obj, subject)
        return false, "cannot " .. op .. " " .. tostring(subject)
    end,
    numerically_indexed = function(obj)
        return false, tostring(obj) .. " is not numerically indexed"
    end,
    empty = function(obj)
        return false, tostring(obj) .. " is empty"
    end,
    binary = function(op, l,r)
        return false, tostring(l) .. " " .. op .. " " .. tostring(r) .. " is not a valid binary operation"
    end,
    prefix = function(op, l)
        return false, op .. " " .. tostring(l) .. " is not a valid prefix operation"
    end,
    postfix = function(op, r)
        return false, op .. " " .. tostring(r) .. " is not a valid postfix operation"
    end,
    literal = function(obj, reason)
        local msg = tostring(obj) .. " is not a literal"
        if reason then
            msg = msg .. " because " .. reason
        end
        return msg
    end,
    string_pattern = function(a, b)
        return false, "cannot find "..tostring(a).." in pattern \"" .. b.pattern_contract .. "\""
    end
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

    local function cmp(a, b, context, source)
        if not context[a] then
            context[a] = {}
            context[a][b] = types.FindInType(a, b, context, source)
        end
        return context[a][b]
    end

    function types.FindInType(a, b, context, source)
        source = source or b
        context = context or {}

        if not a then return false end
        
        if a == b then return source end
            
        if a.upvalue and b.upvalue then

            if a.upvalue_keyref or b.upvalue_keyref then
                return a.upvalue_keyref == b.upvalue_keyref and source or false
            end

            if a.upvalue == b.upvalue then
                return source
            end
        end

        if a.type_checked then
            return cmp(a.type_checked, b, context, a)
        end

        if a.source_left then
            return cmp(a.source_left, b, context, a)
        end

        if a.source_right then
            return cmp(a.source_right, b, context, a)
        end

        if a.source then
            return cmp(a.source, b, context, a)
        end

        return false
    end
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
    types.BaseObject = require("nattlua.types.base")

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

    types.Nil = function() return types.Symbol(nil) end
    types.True = function() return types.Symbol(true) end
    types.False = function() return types.Symbol(false) end
    types.Boolean = function() return types.Union({types.True(), types.False()}):MakeExplicitNotLiteral(true) end
end

function types.View(obj)
    return setmetatable({obj = obj, GetType = function() return obj end}, {
        __index = function(_, key) return types.View(assert(obj:Get(key))) end,
        __newindex = function(_, key, val) assert(obj:Set(key, val)) end,
        __call = function(_, ...) return types.View(assert(obj:Call(...))) end,
    })
end

return types