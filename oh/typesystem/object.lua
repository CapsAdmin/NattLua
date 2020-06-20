local types = require("oh.typesystem.types")
local syntax = require("oh.lua.syntax")
local bit = not _G.bit and require("bit32") or _G.bit

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


Object["*"] = function(l, r, env)
    if l.data ~= nil and r.data ~= nil then
        local res = types.Object:new(l.type, l.data * r.data, l:IsConst() or r:IsConst())

        if l.max and r.max then
            res.max = Object["*"](l.max, r.max, env)
        elseif r.max then
            res.max = Object["*"](l, r.max, env)
        elseif l.max then
            res.max = Object["*"](l.max, r, env)
        end

        return res
    end

    return types.Object:new("any")
end



Object[".."] = function(r, l, env)
    if env == "typesystem" then
        if r.type == "number" and l.type == "number" then
            local new = r:Copy()
            new.max = l
            return new
        end
    end

    if l.data ~= nil and r.data ~= nil then
        return types.Object:new("string", r.data .. l.data, l:IsConst() or r:IsConst())
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

function Object.SubsetOf(A, B)
    if A.type == "any" or A.volatile then
        return true
    end

    if B.Type == "tuple" and B:GetLength() == 1 then
        B = B:Get(1)
    end

    if B.Type == "object" then
        if B.type == "any" or B.volatile then
            return true
        end

        if A.type == B.type then

            if A.const == true and B.const == true then
                -- compare against literals


                -- nan
                if A.type == "number" and B.type == "number" then
                    if A.data ~= A.data and B.data ~= B.data then
                        return true
                    end
                end

                if A.data == B.data then
                    return true
                end

                if A.type == "number" and B.max then
                    if A.data >= B.data and A.data <= B.max.data then
                        return true
                    end
                end

                return types.errors.subset(A, B)
            elseif A.data == nil and B.data == nil then
                -- number contains number
                return true
            elseif A.const and not B.const then
                -- 42 subset of number?
                return true
            elseif not A.const and B.const then
                -- number subset of 42 ?
                return types.errors.subset(A, B)
            end

            -- number == number
            return true
        else
            return false, tostring(A) .. " is not the same type as " .. tostring(B)
        end
        error("this shouldn't be reached ")
    elseif B.Type == "set" then
        return types.Set:new({A}):SubsetOf(B)
    end

    return false
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

function Object:Call(arguments, check_length)
    if self.type == "any" then
        return types.Tuple:new(types.Object:new("any"))
    end

    if self.type == "function"  then
        if self.data.lua_function then
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

            for i,v in ipairs(res) do
                if not types.IsTypeObject(v) then
                    res[i] = types.Create(type(v), v, true)
                end
            end

            return types.Tuple:new(res)
        end

        local A = arguments -- incoming
        local B = self.data.arg -- the contract
        -- A should be a subset of B

        if check_length and A:GetLength() ~= B:GetLength() then
            return false, "invalid amount of arguments"
        end

        for i, a in ipairs(A:GetData()) do
            local b = B:Get(i)
            if not b then
                break
            end

            local ok, reason = a:SubsetOf(b)

            if not ok then
                return false, reason
            end
        end

        return self.data.ret
    end

    return false, "cannot call a nil value"
end

function Object:PrefixOperator(op, val, env)
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

    if op == "~" then
        if self.type == "number" then
            if self.data ~= nil then
                return types.Object:new("number", bit.bnot(self.data))
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

    if op == "-" then
        if env == "typesystem" then
            if self.type == "number" and self.data then
                return types.Object:new(self.type, -self.data, self.const)
            end
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