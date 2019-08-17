local inspect = require("oh.inspect")

local META = {}
META.__index = META

function META:__tostring()
    local types = {}
    for name, values in pairs(self.types) do
        
        local str = {}
        for i,v in ipairs(values) do
            table.insert(str, inspect(v.value, {newline = " ", indent = ""}))
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

end

function META:Set(key, val)

end

function META:IsTruthy()

end

function META:Copy()
    return self
end

function META:AddType(name, value)
    self.types[name] = self.types[name] or {}
    if value == "unknown" then
        self.types[name] = {}
    else
        table.insert(self.types[name], {value = value})
    end
    return self
end

function Object(...)
    local self = setmetatable({}, META)
    self.types = {}

    if ... ~= nil then
        for i,v in ipairs({...}) do
            self:AddType(type(v), v)
        end
    end

    return self
end

local a = Object("lol") .. (Object(1,2,3) + Object(3))

print(Object(true) + Object(false))
--print(Object():AddType("table", {a = true, b = false}))