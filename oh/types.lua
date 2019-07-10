local syntax = require("oh.syntax")

local types = {}

local META = {}
META.__index = META

function META.__add(a, b)
    if not a:IsType(b) then
        return types.Fuse(a, b)
    end

    return a
end

function META:AttachNode(node)
    self.node = node
    return self
end

function META:GetNode()
    return self.node
end

function META:get()
    self:Error("undefined get")

    return types.Type("any"):AttachNode(self:GetNode())
end

function META:set(key, val)
    self:Error("undefined set")
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

function META:Max(max)
    local t = types.Type(self.name, self.value)
    t:AttachNode(self:GetNode())
    t.max = max
    return t
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
    if self.interface.binary and self.interface.binary[op] then
        local arg, ret

        if type(self.interface.binary[op]) == "table" then
            arg, ret = self.interface.binary[op].arg, self.interface.binary[op].ret
        else
            arg = self.interface.binary[op]
            ret = arg
        end

        self:Expect(b, arg)

        if op == "==" and a:IsType("number") and b:IsType("number") and a.value and b.value then
            if a.max then
                return types.Type("boolean", b.value >= a.value and b.value <= a.max.value):AttachNode(self:GetNode())
            end

            if b.max then
                return types.Type("boolean", a.value >= b.value and a.value <= b.max.value):AttachNode(self:GetNode())
            end
        end

        if syntax.CompiledBinaryOperatorFunctions[op] and a.value ~= nil and b.value ~= nil then
            return types.Type(ret, syntax.CompiledBinaryOperatorFunctions[op](a.value, b.value)):AttachNode(self:GetNode())
        end

        return types.Type(ret):AttachNode(self:GetNode())
    end

    self:Error("invalid binary operation " .. op .. " on " .. tostring(b))

    return types.Type("any"):AttachNode(self:GetNode())
end

function META:PrefixOperator(op)
    if self.interface.prefix and self.interface.prefix[op] then
        local ret = self.interface.prefix[op]

        if syntax.CompiledPrefixOperatorFunctions[op] and self.value ~= nil then
            return types.Type(ret, syntax.CompiledPrefixOperatorFunctions[op](self.value)):AttachNode(self:GetNode())
        end

        return types.Type(ret):AttachNode(self:GetNode())
    end

    self:Error("invalid prefix operation " .. op)

    return types.Type("any"):AttachNode(self:GetNode())
end

function META:PostfixOperator(op)
    if self.interface.postfix and self.interface.postfix[op] then
        local ret = self.interface.postfix[op]

        if syntax.CompiledPostfixOperatorFunctions[op] and self.value ~= nil then
            return types.Type(ret, syntax.CompiledPostfixOperatorFunctions[op](self.value)):AttachNode(self:GetNode())
        end

        return types.Type(ret):AttachNode(self:GetNode())
    end

    self:Error("invalid postfix operation " .. op)

    return types.Type("any"):AttachNode(self:GetNode())
end

function META:Expect(type, expect)
    if not type:IsType(expect) then
        self:Error("expected " .. expect .. " got " .. type.name)
    end
end

function META:Error(msg)
    local s = tostring(self)

    if self:GetNode() then
        s = s .. " - " .. self:GetNode():Render() .. " - "
    end

    s = s .. ": " .. msg

    print(s)
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
    prefix = {
        ["not"] = "boolean",
    },
})


types.Register("any", {
    inherits = "base",
    truthy = true,
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
        if structure then
            for key, val in pairs(structure) do
                if val[1] == "self" then
                    structure[key] = self
                end
            end
        end
        return {structure = structure, value = {}}
    end,
    set = function(self, key, val)
        if not self.structure then
            local key = type(key) ~= "string" and key.value or key
            self.value[key] = val
        elseif type(key) == "string" or self.structure[key.value] then
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
        if self.structure and not self.structure[key] then
            self:Error("invalid index " .. tostring(key))
        end

        local key = type(key) ~= "string" and key.value or key

        if self.value[key] == nil then
            return types.Type("any"):AttachNode(self:GetNode())
        end

        return self.value[key]
    end,
    tostring = function(self)
        if self.during_tostring then return "*self" end

        self.during_tostring = true
        local str = {"table {"}
        for k, v in pairs(self.value) do
            local key = tostring(k)

            if type(k) == "table" then
                key = "[" .. key .. "]"
            elseif v == self then
                v = "*self"
            end

            table.insert(str, key .. " = " .. tostring(v) .. ",")
        end
        table.insert(str, "}")

        self.during_tostring = false
        return table.concat(str, " ")
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

    init = function(self, ret, arguments, func)
        return {ret = ret, arguments = arguments, func = func}
    end,

    tostring = function(self)
        local arg_str = {}

        if self.arguments then
            for i, v in ipairs(self.arguments) do
                arg_str[i] = tostring(v)
            end
        end

        local ret_str = {}

        if self.ret then
            for i, v in ipairs(self.ret) do
                ret_str[i] = tostring(v)
            end
        end

        return self.name .. "(" .. table.concat(arg_str, ", ") .. "): " .. table.concat(ret_str, ", ")
    end,
})

function types.MatchFunction(functions, arguments)
    for _, func in ipairs(functions) do
        local ok = false
        for i, type in ipairs(arguments) do
            if func.arguments and func.arguments[i] and func.arguments[i]:IsType(type) then
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