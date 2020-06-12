local types = require("oh.typesystem.types")
local syntax = require("oh.lua.syntax")

local Object = {}
Object.Type = "object"
Object.__index = Object

Object["%"] = function(l, r, env)
    if l.data ~= nil and r.data ~= nil then
        return types.Object:new("number", l.data % r.data)
    end
    local t = types.Object:new("number", 0)
    t.max = l:Copy()
    return t
end

Object["^"] = function(l, r, env)
    if l.data ~= nil and r.data ~= nil then
        return types.Object:new("number", l.data ^ r.data)
    end
    return types.Object:new("any")
end


Object["/"] = function(l, r, env)
    if l.data ~= nil and r.data ~= nil then
        return types.Object:new("number", l.data / r.data)
    end
    return types.Object:new("any")
end



Object[".."] = function(r, l, env)
    if l.data ~= nil and r.data ~= nil then
        return types.Object:new("string", r.data .. l.data)
    end
    return types.Object:new("any")
end

local function generic(op)
    Object[op] = load([[local types = ...; return function(l,r,env)
        if l.data ~= nil and r.data ~= nil then
            return types.Object:new("boolean", l.data ]]..op..[[ r.data)
        end

        return types.Object:new("boolean")
    end]])(types)
end

generic(">")
generic("<")
generic(">=")
generic("<=")


function Object:GetSignature()
    if self.type == "function" then
        return self.type .. "-"..types.GetSignature(self.data)
    end
    if self.const then
        return self.type .. "-" .. types.GetSignature(self.data)
    end

    return self.type
end

function Object:SetType(name)
    assert(name)
    self.type = name
end

function Object:IsType(name)
    return self.type == name
end

function Object:GetLength()
    return 0
end

function Object:Get(key)
    local val = type(self.data) == "table" and self.data:Get(key)

    if not val and self.meta then
        local index = self.meta:Get("__index")
        if index.Type == "dictionary" then
            return index:Get(key)
        end
    end

    return val
end

function Object:Set(key, val)
    if self.type == "any" then
        return false, "any[" .. tostring(key) .. "] = " .. tostring(val)
    end
    return self.data:Set(key, val)
end

function Object:GetArguments()
    return self.data.arg
end

function Object:GetReturnTypes()
    return self.data.ret
end

function Object:GetData()
    return self.data
end

function Object:Copy()
    local data = self.data

    if self.type == "function" then
        data = {ret = data.ret:Copy(), arg = data.arg:Copy()}
    end

    local copy = Object:new(self.type, data, self.const)
    copy.volatile = self.volatile
    return copy
end

function Object:SupersetOf(sub)
    if sub.Type == "tuple" and sub:GetLength() == 1 then
        sub = sub.data[1]
    end

    if self.type == "any" or self.volatile then
        return true
    end

    if sub.Type == "set" then
        return sub:Get(self) ~= nil
    end

    if sub.Type == "object" then
        if sub.type == "any" or sub.volatile then
            return true
        end

        if self.type == sub.type then

            if self.const == true and sub.const == true then

                if self.data == sub.data then
                    return true
                end

                if self.type == "number" and sub.type == "number" and self.max then
                    if sub.data > self.data and sub.data < self.max.data then
                        return true
                    end
                end
            end

            -- "5" must be within "number"
            if self.data == nil and sub.data ~= nil then
                return true
            end

            -- self = number(1)
            -- sub = 1
            if self.data ~= nil and self.data == sub.data then
                return true
            end

            if sub.data == nil or self.data == nil then
                return true
            end

            if not self.const and not sub.const then
                return true
            end
        end

        return false
    end

    return false
end

function Object.SubsetOf(a,b)
    return b:SupersetOf(a)
end

function Object:__tostring()
    --return "「"..self.uid .. " 〉" .. self:GetSignature() .. "」"

    if self.type == "function" then
        return "function" .. tostring(self.data.arg) .. ": " .. tostring(self.data.ret)
    end


    if self.volatile then
        local str = self.type

        if self.data ~= nil then
            str = str .. "(" .. tostring(self.data) .. ")"
        end

        str = str .. "💥"

        return str
    end

    if self.const then
        if self.type == "string" then
            if self.data then
                return ("%q"):format(self.data)
            end
        end

        if self.data == nil then
            return self.type
        end

        return tostring(self.data) .. (self.max and (".." .. tostring(self.max.data)) or "")
    end

    if self.data == nil then
        return self.type
    end

    return self.type .. "(".. tostring(self.data) .. (self.max and (".." .. self.max.data) or "") .. ")"
end

function Object:Serialize()
    return self:__tostring()
end

do
    Object.truthy = 0

    function Object:GetTruthy()
        return self.truthy > 0
    end

    function Object:PushTruthy()
        self.truthy = self.truthy + 1
    end
    function Object:PopTruthy()
        self.truthy = self.truthy + 1
    end
end

function Object:Max(val)
    if self.type == "number" then
        self.max = val
    end
    return self
end

function Object:IsVolatile()
    return self.volatile == true
end

function Object:IsFalsy()
    if self.type == "nil" then
        return true
    end

    if self.type == "boolean" and self.data == false or self.data == nil then
        return true
    end

    return false
end

function Object:IsTruthy()
    if self.type == "nil" then
        return false
    end

    if self.type == "boolean" then
        if self.data == false then
            return false
        end

        if self.data == nil then
            return true
        end
    end

    return true
end

function Object:RemoveNonTruthy()
    return self
end

function Object:IsConst()
    return self.const == true
end

function Object:Call(arguments)
    if self.type == "any" then
        return types.Tuple:new(types.Object:new("any"))
    end

    if self.type == "function" and self.data.lua_function then
        _G.self = require("oh").current_analyzer
        local res = {pcall(self.data.lua_function, table.unpack(arguments.data))}
        _G.self = nil

        if not res[1] then
            return false, res[2]
        end

        if not res[2] then
            res[2] = types.Object:new("nil")
        end

        table.remove(res, 1)

        return types.Tuple:new(res)
    end

    for i, arg in ipairs(self.data.arg:GetData()) do
        if not arguments[i] then
            break
        end

        if  not arg:SupersetOf(arguments[i]) then
            return false, "cannot call " .. tostring(self) .. " with arguments " ..  tostring(arguments)
        end

    end

    return self.data.ret
end

function Object:PrefixOperator(op, val)
    if op == "#" then
        if self.type == "string" then
            if self.const then
                if self.data then
                    return types.Object:new("number", #self.data, true)
                end
            end
            return types.Object:new("number")
        end

        return types.Object:new("any")
    end

    if op == "not" then
        if self:IsTruthy() and self:IsFalsy() then
            return types.Object:new("boolean")
        end

        if self:IsTruthy() then
            return types.Object:new("boolean", false, true)
        end

        if self:IsFalsy() then
            return types.Object:new("boolean", true, true)
        end
    end

    if syntax.CompiledPrefixOperatorFunctions[op] and val.data ~= nil then
        local ok, res = pcall(syntax.CompiledPrefixOperatorFunctions[op], val.data)

        if not ok then
            return false, res
        else
            return types.Object:new(val.type, res)
        end
    end

    return false, "NYI " .. op .. ": " .. tostring(val)
end

local uid = 0

function Object:new(type, data, const)
    local self = setmetatable({}, self)

    uid = uid + 1

    self.uid = uid
    self:SetType(type)
    self.data = data
    self.const = const

    return self
end

for k,v in pairs(types.BaseObject) do Object[k] = v end
types.Object = Object

return Object