local syntax = require("oh.syntax")

local types = {}

local META = {}
META.__index = META

function META.__add(a, b)
    return types.Fuse(a, b)
end

function META:__tostring()
    if self.interface.tostring then
        return self.interface.tostring(self)
    end

    if self.value ~= nil then
        return self.name .. "(" .. tostring(self.value) .. ")"
    end
    return self.name
end

function META:GetTypes()
    return {self.name}
end

function META:IsType(what)
    if type(what) == "table" then
        for i,v in ipairs(what:GetTypes()) do
            if self:IsType(v) then
                return true
            end
        end
    end
    return self.interface.type_map[what]
end

function META:IsCompatible(type)
    return self:IsType(type) and type:IsType(self)
end

function META:IsTruthy()
    if type(self.interface.truthy) == "table" then
        if self.value == nil then
            return self.interface.truthy._nil
        end
        return self.interface.truthy[self.value]
    end

    return self.interface.truthy
end

function META:BinaryOperator(op, b)
    local a = self
    if self.interface.binary[op] then
        local arg, ret

        if type(self.interface.binary[op]) == "table" then
            arg, ret = self.interface.binary[op].arg, self.interface.binary[op].ret
        else
            arg = self.interface.binary[op]
            ret = arg
        end

        self:Expect(b, arg)

        if syntax.CompiledBinaryOperatorFunctions[op] and a.value ~= nil and b.value ~= nil then
            return types.Type(ret, syntax.CompiledBinaryOperatorFunctions[op](a.value, b.value))
        end

        return types.Type(ret)
    end

    self:Error("invalid binary operation " .. op)
end

function META:PrefixOperator(op)
    if self.interface.prefix[op] then
        local ret = self.interface.prefix[op]

        if syntax.CompiledPrefixOperatorFunctions[op] and self.value ~= nil then
            return types.Type(ret, syntax.CompiledPrefixOperatorFunctions[op](self.value))
        end

        return types.Type(ret)
    end

    self:Error("invalid prefix operation " .. op)
end

function META:PostfixOperator(op)
    if self.interface.postfix[op] then
        local ret = self.interface.postfix[op]

        if syntax.CompiledPostfixOperatorFunctions[op] and self.value ~= nil then
            return types.Type(ret, syntax.CompiledPostfixOperatorFunctions[op](self.value))
        end

        return types.Type(ret)
    end

    self:Error("invalid postfix operation " .. op)
end

function META:Expect(type, expect)
    if not type:IsType(expect) then
        self:Error("expected " .. expect .. " got " .. type.name)
    end
end

function META:Error(msg)
    error(tostring(self) .. ": " .. msg)
end

local registered = {}

function types.Register(name, interface)

    interface.type_map = {
        [name] = true,
    }

    if interface.inherits then

        interface.type_map[interface.inherits] = true

        local function merge(a, b)
            for k,v in pairs(b) do
                if type(v) == "table" and type(a[k]) == "table" then
                    merge(a[k], v)
                else
                    a[k] = v
                end
            end

            return a
        end

        local base = assert(registered[interface.inherits], "base type " .. interface.inherits .. " does not exist")

        interface = merge(interface, base.interface)
    end

    registered[name] = {
        interface = interface,
        new = function(...)
            local self = setmetatable({interface = interface}, META)

            if interface.init then
                for k,v in pairs(interface.init(self, ...)) do
                    self[k] = v
                end

                self.get = interface.get
                self.set = interface.set
            else
                self.value = ...
            end

            self.name = name

            return self
        end,
    }

    return registered[name].new
end

function types.Type(name, ...)
    assert(registered[name], "type " .. name .. " does not exist")
    return registered[name].new(...)
end

do
    local META = {}
    META.__index = META

    local function invoke(self, name, ...)
        for _, type in ipairs(self.types) do
            local ret = type[name](type, ...)
            if ret ~= nil then
                return ret
            end
        end
    end

    function META:__tostring()
        local str = {}

        for i, type in ipairs(self.types) do
            str[i] = tostring(type)
        end

        return table.concat(str, " | ")
    end

    function META:IsTruthy()
        return invoke(self, "IsTruthy")
    end

    function META:IsType(...)
        return invoke(self, "IsTruthy", ...)
    end

    function META:GetTypes()
        local types = {}
        for i, type in ipairs(self.types) do
            types[i] = type.name
        end
        return types
    end

    function META:BinaryOperator(...)
        return invoke(self, "BinaryOperator", ...)
    end

    function META:PrefixOperator(...)
        return invoke(self, "PrefixOperator", ...)
    end

    function META:PostfixOperator(...)
        return invoke(self, "PostfixOperator", ...)
    end

    function types.Fuse(...)
        return setmetatable({types = {...}}, META)
    end
end

types.Register("base", {
    binary = {
        ["=="] = {arg = "base", ret = "boolean"},
        ["~="] = {arg = "base", ret = "boolean"},
    },
})

types.Register("string", {
    inherits = "base",
    truthy = true,
    binary = {
        [".."] = "string",

        ["<"] = "boolean",
        [">"] = "boolean",
        ["<="] = "boolean",
        [">="] = "boolean",
    },
    prefix = {
        ["#"] = "number",
    },
})

types.Register("table", {
    inherits = "base",
    truthy = true,
    prefix = {
        ["#"] = "number",
    },
    init = function(self, structure)
        for key, val in pairs(structure) do
            if val[1] == "self" then
                structure[key] = self
            end
        end
        return {structure = structure, value = {}}
    end,
    set = function(self, key, val)
        if type(key) == "string" or self.structure[key.value] then
            local key = type(key) ~= "string" and key.value or key

            if not self.structure[key] then
                self:Error("index " .. tostring(key) .. " is not defined")
            end

            if not self.structure[key]:IsCompatible(val) then
                self:Error("invalid index " .. tostring(key) .. " expected " .. tostring(self.structure[key]) .. " got " .. tostring(val))
            end

            self.value[key] = val
        else
            local found = nil
            for v in pairs(self.structure) do
                if key:IsCompatible(v) then
                    found = key
                    break
                end
            end

            if not found then
                self:Error("index " .. tostring(key) .. " is not defined")
            end

            if not found:IsCompatible(val) then
                self:Error("invalid index " .. tostring(key) .. " expected " .. tostring(found) .. " got " .. tostring(val))
            end

            self.value[found] = val
        end
    end,
    get = function(self, key, val)
        if not self.structure[key] then
            self:Error("invalid index " .. tostring(key))
        end

        return self.value[key]
    end,
    tostring = function(self)
        local str = {"table {"}
        for k, v in pairs(self.value) do
            local key = tostring(k)

            if type(k) == "table" then
                key = "[" .. key .. "]"
            elseif v == self then
                v = "*self"
            end

            table.insert(str, "\t" .. key .. " = " .. tostring(v) .. ",")
        end
        table.insert(str, "}")
        return table.concat(str, "\n")
    end,
})

types.Register("boolean", {
    inherits = "base",
    truthy = {
        [true] = true,
        [false] = false,
        _nil = true,
    },
})

types.Register("nil", {
    inherits = "base",
    truthy = false,
})

types.Register("number", {
    inherits = "base",
    truthy = true,
    binary = {
        ["+"] = {arg = "number", ret = "number"},
        ["-"] = "number",
        ["*"] = "number",
        ["/"] = "number",

        ["<"] = "boolean",
        [">"] = "boolean",
        ["<="] = "boolean",
        [">="] = "boolean",
    }
})

types.Register("...", {
    inherits = "base",
})

types.Register("function", {
    inherits = "base",
    truthy = true,

    init = function(self, ret, arguments)
        return {ret = ret or _nil(), arguments = arguments or {}}
    end,

    tostring = function(self)
        local str = {}

        for i, v in ipairs(self.arguments) do
            str[i] = tostring(v)
        end

        return self.name .. "(" .. table.concat(str, ", ") .. "): " .. tostring(self.ret)
    end,
})

function types.MatchFunction(functions, arguments)
    for _, func in ipairs(functions) do
        local ok = false
        for i, type in ipairs(arguments) do
            if func.arguments[i] and func.arguments[i]:IsType(type) then
                ok = true
            else
                ok = false
                break
            end
        end
        if ok then
            return func
        end
    end
end

setmetatable(types, {
    __call = function(_, ...)
        return types.Type(...)
    end,
    __index = function(_, key)
        if registered[key] then
            return registered[key].new
        end
    end,
})

return types