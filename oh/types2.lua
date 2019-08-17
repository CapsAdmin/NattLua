local inspect = require("oh.inspect")

local META = {}

META.__index = META

local process = function(item, path) if getmetatable(item) == META then return tostring(item) end return item end

function META:__tostring()
    local types = {}
    for name, values in pairs(self.types) do

        local str = {}
        for i,v in ipairs(values) do
            if v.value ~= nil then
                table.insert(str, inspect(v.value, {newline = " ", indent = "", process = process}))
            end
        end

        local values = table.concat(str, ", ")

        if #values > 0 then
            values = "(" .. values .. ")"
        end

        table.insert(types, name .. values)
    end

    local str = table.concat(types, " | ")

    return self.id .. "-" .. str
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
                local key = b.value.value or ("-_T" .. b.type)

                if self.signature and not self.signature[key] then
                    print("cannot index with ", key) -- todo expected
                elseif self.signature and self.signature[key] and not self.signature[key]:Extends(val) then
                    print("cannot assign ", key, " = ", val) -- todo expected
                elseif a.value.value[key] then
                    a.value.value[key]:AddType(val)
                else
                    a.value.value[key] = val
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

function META:AddType(name, value)
    if getmetatable(name) == META then
        for k,v in ipairs(name:GetValues()) do
            self:AddType(v.type, v.value.value)
        end
        return
    end
    self.types[name] = self.types[name] or {}
    if value == "unknown" then
        self.types[name] = {}
    else
        table.insert(self.types[name], {value = value})
    end
    return self
end

function META:LockSignature()
    local signature = {}
    for _, a in pairs(self:GetValues()) do
        if a.type == "table" then
            for k,v in pairs(a.value.value) do
                signature[k] = v
            end
        end
    end
    self.signature = signature
end

function META:Extends(t)
    for _, a in pairs(self:GetValues()) do
        for _, b in pairs(t:GetValues()) do
            if a.type ~= b.type then
                return false
            end
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

local a = Object("lol") .. (Object(1,2,3) + Object(3))

--print(a)
--print(a:Copy())

local a = Object({})
local b = Object({})
print(a:Extends(b))

a:Set(Object():AddType("string"), Object(true))
a:LockSignature()
a:Set(Object():AddType("number"), Object(true))
a:Set(Object():AddType("string"), Object(""))


print(a)
--print(Object():AddType("table", {a = true, b = false}))