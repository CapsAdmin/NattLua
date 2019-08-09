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
    if node then
        node.inferred_type = self
    end

    return self
end

function META:GetNode()
    return self.node
end

function META:get()
    self:Error("undefined get")

    return self:Type("any")
end

function META:set(key, val)
    self:Error("undefined set")
end

function META:GetReadableContent()
    if self.value ~= nil then
        return self.value
    end

    return self.name
end

function META:__tostring()
    if self.interface.tostring then
        return self.interface.tostring(self)
    end

    if self.value ~= nil then
        local val = tostring(self.value)
        if self.max then
            val = val .. ".." .. tostring(self.max.value)
        end

        return self.name .. "(" .. val .. ")"
    end

    return self.name
end

function META:GetTypes()
    return {self.name}
end

function META:IsType(what)
    if type(what) == "table" then
        for _,v in ipairs(what:GetTypes()) do
            if self:IsType(v) then
                return true
            end
        end
    end

    if what == "any" then
        return true
    end

    return self.interface.type_map[what]
end

function META:IsCompatible(type)
    return self:IsType(type) and type:IsType(self)
end

function META:Type(...)
    local t = types.Type(...)
    t:AttachNode(self:GetNode())
    return t
end

function META:Max(max)
    local t = self:Type(self.name, self.value)
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

function META:BinaryOperator(op, b, node, env)
    local a = self

    if env == "typesystem" then
        if op == "|" then
            return types.Fuse(a, b)
        end
    end

    if self.interface.binary and self.interface.binary[op] then
        local arg, ret

        if type(self.interface.binary[op]) == "table" then
            arg, ret = self.interface.binary[op].arg, self.interface.binary[op].ret
        else
            arg = self.interface.binary[op]
            ret = arg
        end

        if not b:IsType(arg) then
            self:Error(tostring(self) .. " " .. op .. " " .. tostring(b) .." is not a valid binary operation (expected " .. arg .. ")")
            return self:Type("any")
        end

        if op == "==" and a:IsType("number") and b:IsType("number") and a.value and b.value then
            if a.max and a.max.value then
                return self:Type("boolean", b.value >= a.value and b.value <= a.max.value)
            end

            if b.max and b.max.value then
                return self:Type("boolean", a.value >= b.value and a.value <= b.max.value)
            end
        end

        if syntax.CompiledBinaryOperatorFunctions[op] and a.value ~= nil and b.value ~= nil then
            local ok, res = pcall(syntax.CompiledBinaryOperatorFunctions[op], a.value, b.value)
            if not ok then
                self:Error(res)
            else
                return self:Type(ret, res)
            end
        end

        return self:Type(ret)
    end

    self:Error("invalid binary operation " .. tostring(b:GetReadableContent()) .. op .. tostring(a:GetReadableContent()))

    return self:Type("any")
end

function META:PrefixOperator(op)
    if self.interface.prefix and self.interface.prefix[op] then
        local ret = self.interface.prefix[op]

        if syntax.CompiledPrefixOperatorFunctions[op] and self.value ~= nil then
            local ok, res = pcall(syntax.CompiledPrefixOperatorFunctions[op], self.value)
            if not ok then
                self:Error(res)
            else
                return self:Type(ret, res)
            end
        end

        return self:Type(ret)
    end

    self:Error("invalid prefix operation " .. op)

    return self:Type("any")
end

function META:PostfixOperator(op)
    if self.interface.postfix and self.interface.postfix[op] then
        local ret = self.interface.postfix[op]

        if syntax.CompiledPostfixOperatorFunctions[op] and self.value ~= nil then
            local ok, res = pcall(syntax.CompiledPostfixOperatorFunctions[op], self.value)
            if not ok then
                self:Error(res)
            else
                return self:Type(ret, res)
            end
        end

        return self:Type(ret)
    end

    self:Error("invalid postfix operation " .. op)

    return self:Type("any")
end

function META:Expect(type, expect)
    if not type:IsType(expect) then
        self:Error("expected " .. expect .. " got " .. type.name)
    end
end

function META:Error(msg)

    if self:GetNode() and self.code then
        local print_util = require("oh.print_util")
        local node = self:GetNode()
        local start, stop = print_util.LazyFindStartStop(node)
        io.write(print_util.FormatError(self.code, self.name, msg, start, stop))
    else
        local s = tostring(self)
        s = s .. ": " .. msg

        print(s)
    end
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

function types.IsType(name)
    return registered[name]
end

function types.Type(name, ...)
    assert(registered[name], "type " .. name .. " does not exist")
    return registered[name].new(...)
end

function types.OverloadFunction(a, b)
    a.overloads = a.overloads or {a}
    table.insert(a.overloads, b)

    return a
end

function types.CallFunction(func, args)
    local errors = {}
    local found

    for _, func in ipairs(func.overloads or {func}) do
        local ok = true

        for i, typ in ipairs(func.arguments) do
            if not args[i] or not typ:IsType(args[i]) then
                ok = false
                table.insert(errors, {func = func, err = {"expected " .. tostring(typ) .. " to argument #"..i.." got " .. tostring(args[i])}})
            end
        end

        if ok then
            found = func
            break
        end
    end

    if not found then
        for _, data in ipairs(errors) do
            data.func:Error(unpack(data.err))
        end
        return {func:Type("any")}
    end

    return found.ret
end

do
    local META = {}
    META.__index = META

    local function invoke(self, name, ...)
        local types = {}
        local done = {}
        for _, type in ipairs(self.types) do
            local ret = type[name](type, ...)
            if ret ~= nil then
                for k,v in pairs(ret.types or {ret}) do
                    if not done[v.name] then
                        table.insert(types, v)
                        done[v.name] = true
                    end
                end
            end
        end

        if types[1] then
            return setmetatable({types = types}, META)
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

    function types.Fuse(a, b)
        local types = {}
        for i,v in ipairs(a.types or {a}) do
            table.insert(types, v)
        end
        for i,v in ipairs(b.types or {b}) do
            table.insert(types, v)
        end
        return setmetatable({types = types}, META)
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
    get = function(self, key)
        if self.structure and not self.structure[key] then
            self:Error("invalid index " .. tostring(key))
        end

        key = type(key) ~= "string" and key.value or key

        if self.value[key] == nil then
            return self:Type("any")
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

do
    local function check_index(self, key)
        if not key:IsType("number") then
            self:Error("cannnot index " .. tostring(key) .. " on array")
        elseif self.length and key.value and key.value > self.length then
            self:Error("out of bounds " .. tostring(key))
        elseif key.value and key.value < 1 then
            self:Error("out of bounds " .. tostring(key))
        end
    end

    types.Register("list", {
        inherits = "base",
        truthy = true,
        prefix = {
            ["#"] = "number",
        },
        init = function(self, type, length)
            return {list_type = type, length = length}
        end,
        set = function(self, key, val)
            check_index(self, key)

            if self.list_type and not val:IsType(self.list_type) then
                self:Error("expected " .. tostring(self.list_type) .. " got " .. tostring(val))
            end

            self.value[key] = val
        end,
        get = function(self, key)
            check_index(self, key)

            return self.value[key]
        end,
        tostring = function(self)
            return (tostring(self.list_type) or "") .. "["..(self.length and self.length or "").."]"
        end,
    })
end

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
    prefix = {
        ["-"] = "number",
    },
    binary = {
        ["+"] = "number",
        ["-"] = "number",
        ["*"] = "number",
        ["/"] = "number",

        ["<"] = {arg = "number", ret = "boolean"},
        [">"] = {arg = "number", ret = "boolean"},
        ["<="] = {arg = "number", ret = "boolean"},
        [">="] = {arg = "number", ret = "boolean"},
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