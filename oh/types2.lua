local inspect = require("oh.inspect")

local META = {}

META.__index = META

local process = function(item, path) if getmetatable(item) == META then return tostring(item) end return item end

function META:Serialize()
    local types = {}
    for name, values in pairs(self.types) do

        local str = {}
        for i,v in ipairs(values) do
            if v.value ~= nil then
                if name == "function" then
                    local arg = {}
                    for i,v in ipairs(v.value.arg) do
                        arg[i] = v:Serialize()
                    end

                    local ret = {}
                    for i,v in ipairs(v.value.ret) do
                        ret[i] = v:Serialize()
                    end

                    table.insert(str, "function(" .. table.concat(arg, ", ") .. "): " .. table.concat(ret, ", "))
                else
                    table.insert(str, inspect(v.value, {newline = " ", indent = "", process = process}))
                end
            end
        end

        local values = table.concat(str, ", ")

        if #values > 0 then
            values = "(" .. values .. ")"
        end

        table.insert(types, name .. values)
    end

    local str = table.concat(types, " | ")

    return str
end

function META:__tostring()
    return "「"..self.id .. " 〉" .. self:Serialize() .. "」"
end

function META.__add(a, b) return a:BinaryOperator("+", b) end
function META.__sub(a, b) return a:BinaryOperator("-", b) end
function META.__concat(a, b) return a:BinaryOperator("..", b) end

function META:Call(...)

end

function META:GetValues()
    local out = {}

    for name, values in pairs(self.types) do
        for i, value in ipairs(values) do
            table.insert(out, {type = name, value = value})
        end
    end

    return out
end

local function binary(a, op, b)
    local ok, err = pcall(loadstring("local a, b = ... return a " .. op .. " b"), a, b)
    if not ok then
        err = err:match(".-:1: (.+)")
    end
    return ok, err
end

function META.BinaryOperator(a, op, b)
    local copy = Object()
    local values = a:GetValues()

    for _, a in pairs(a:GetValues()) do
        for i, b in pairs(b:GetValues()) do
            local new = {value = {}}

            if a.value.value == nil or b.value.value == nil then
                new.type = a.type
                new.value.value = "unknown"
            else
                local ok, res = binary(a.value.value, op, b.value.value)
                if ok then
                    new.type = a.type
                    new.value.value = res
                else
                    new.type = "error"
                    new.value.value = res
                end
            end

            if values[i] then
                table.remove(values, i)
            end

            table.insert(values, new)
        end
    end

    for _, v in ipairs(values) do
        copy:AddType(v.type, v.value.value)
    end

    return copy
end

function META.PrefixOperator(a, op)

end

function META.PostfixOperator(a, op)

end

function META:Get(key)
    for _, a in pairs(self:GetValues()) do
        print(a)
    end
end

function META:Set(key, val)
    for _, a in pairs(self:GetValues()) do
        for _, b in pairs(key:GetValues()) do
            local ok, err = pcall(function()
                local key = b.constant and b.value.value or "⊤" .. b.type

                if self.signature and not self.signature[key] then
                    print("cannot index with ", key) -- todo expected
                elseif self.signature and self.signature[key] and not self.signature[key]:Extends(val) then
                    print("cannot assign ", key, " = ", val) -- todo expected
                elseif a.value.value[key] and val ~= nil then
                    a.value.value[key]:AddType(val)

                    if b.value.value and not b.constant then
                        a.value.value[b.value.value] = a.value.value[key]
                    end
                else
                    a.value.value[key] = val

                    if b.value.value and not b.constant then
                        a.value.value[b.value.value] = a.value.value[key]
                    end
                end
            end)
            if not ok then
                print(err)
            end
        end
    end
end

function META:IsTruthy()

end

function META:Copy()
    local copy = Object()
    local values = self:GetValues()

    for _, v in ipairs(values) do
        copy:AddType(v.type, v.value.value)
    end
    return copy
end

function META:AddType(name, value, constant)
    if getmetatable(name) == META then
        for k,v in ipairs(name:GetValues()) do
            self:AddType(v.type, v.value.value, v.constant)
        end
        return
    end
    self.types[name] = self.types[name] or {}
    if value == "unknown" then
        self.types[name] = {}
    else
        table.insert(self.types[name], {value = value, constant = constant})
    end
    return self
end

function META:GetSignature()
    local signature = {}
    for _, a in pairs(self:GetValues()) do
        if a.type == "table" then
            for k,v in pairs(a.value.value) do
                signature[k] = v
            end
        end
    end
    return signature
end

function META:LockSignature()
    self.signature = self:GetSignature()
end

function META:Exclude(t)
    for _, val in ipairs(t:GetValues()) do
       self.types[val.type] = nil
    end
    return self
end

function META:Error(...)
    print(...)
end

function META:__call(args)
    local errors = {}
    local found

    for _, val in ipairs(self:GetValues()) do
        if val.type == "function" then
            local ok = true

            for i, typ in ipairs(val.value.value.arg) do
                if (not args[i] or not typ:Extends(args[i])) and not typ:Extends(Object():AddType("any")) then
                    ok = false
                    table.insert(errors, {func = val, err = {"expected " .. tostring(typ) .. " to argument #"..i.." got " .. tostring(args[i])}})
                end
            end

            if ok then
                found = val
                break
            end
        end
    end

    if not found then
        for _, data in ipairs(errors) do
            self:Error(unpack(data.err))
        end
        return {Object():AddType("any")}
    end

    local ret = found.value.value.ret
    return ret
end

function META:Extends(t)
    for _, a in ipairs(self:GetValues()) do
        for _, b in ipairs(t:GetValues()) do
            if a.type ~= b.type then
                return false
            end
        end
    end

    local sig = t:GetSignature()
    for k, v in pairs(self:GetSignature()) do
        if sig[k] == nil then
            return false
        end

        if not sig[k]:Extends(v) then
            return false
        end
    end

    return true
end
local ref = 0

function Object(...)
    ref = ref + 1
    local self = setmetatable({id = ref}, META)
    self.types = {}

    if ... ~= nil then
        for i,v in ipairs({...}) do
            self:AddType(type(v), v)
        end
    end

    return self
end

local T = function(str) return Object():AddType(str) end
local V = Object

local f = Object()
f:AddType("function", {arg = {T"string", T"number"}, ret = {T"boolean"}, func = print})
f:AddType("function", {arg = {T"number"}, ret = {T"string"}, func = print})

print(unpack(f({T"string", T"number"})))


do return end

local a = Object("lol") .. (Object(1,2,3) + Object(3))

--print(a)
--print(a:Copy())

local a = V({})
local b = V({})

print(a:Extends(b))

a:Set(T"string", V(true))
a:Set(T"number", V(true))
a:LockSignature()

a:Set(T"number", V(true))
--a:Set(T"string", V(""))


b:Set(T"string", T"boolean")
b:Set(V(55), T"boolean")
print(a:Extends(b))
print(a)
print(b)

print(V(1):Extends(T("number")))

print(T("number"):AddType("string"):Exclude(T"string"):Extends(T"number"))

--print(Object():AddType("table", {a = true, b = false}))