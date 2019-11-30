local syntax = require("oh.syntax")


local function Error(self, msg, node)
    local node = node or self.GetNode and self:GetNode()

    if self.analyzer then
        self.analyzer:Error(node, msg)
        return
    end

    if node and self.code then
        local print_util = require("oh.print_util")
        local start, stop = print_util.LazyFindStartStop(node)
        io.write(print_util.FormatError(self.code, self.name, msg, start, stop))
    else
        local s = tostring(self)
        s = s .. ": " .. msg

        print(s)
    end
end

local types = {}


function types.IsTypeObject(val)
    return getmetatable(val) == types.fuse_meta or getmetatable(val) == types.type_meta
end

function types.ReplaceType(a, b)
    if a then
        a:Replace(b)
        return a
    end

    return b
end

local META = {}
META.__index = META

types.type_meta = META

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

function META:get(key)
    key:Error("undefined get: "..tostring(self).."[" .. tostring(key) .. "]")
    return self:Type("any")
end

function META:set(key, val)
    key:Error("undefined set: "..tostring(self).."[" .. tostring(key) .. "] = " .. tostring(val))
end

function META:GetReadableContent()
    if self.value ~= nil then
        if self.name == "string" then
            return '"' .. self.value .. '"'
        end
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

do

    local function deepcopy(orig)
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            if types.IsTypeObject(orig) then
                copy = orig:Copy()
            else
                copy = {}
                for orig_key, orig_value in pairs(orig) do
                    copy[deepcopy(orig_key)] = deepcopy(orig_value)
                end
            end
        else -- number, string, boolean, etc
            copy = orig
        end
        return copy
    end

    function META:Copy()
        if self.name == "function" then
            return types.Create(self.name, deepcopy(self.ret), deepcopy(self.args), self.func)
        else
            return types.Create(self.name, deepcopy(self.value))
        end
    end
end

function META:Replace(t)
    for k,v in pairs(self) do
        self[k] = nil
    end

    for k,v in pairs(t) do
        self[k] = v
    end
end

function META:GetTypes()
    return {self.name}
end

function META:IsType(what, explicit)
    if type(what) == "table" then
        if self.LOL then return false end

        if what.name == "table" and self.name == "table" and what.value and self.value then
            local subset = self
            local superset = what

            for super_key, super_val in pairs(superset.value) do
                local sub_val = self:get(super_key)

                self.LOL = true

                if not sub_val:IsCompatible(super_val) then
                    self.LOL = false
                    return false
                end


                if super_val.name ~= "table" and super_val.value ~= nil and sub_val.value ~= super_val.value then
                    self.LOL = false
                    return false
                end

            end
            self.LOL = false
            return true
        else
            for _,v in ipairs(what:GetTypes()) do
                if self:IsType(v, explicit) then
                    return true
                end
            end
        end
    end

    if self.name == "table" and what == "list" then
        return true
    end

    if not explicit and (what == "any" or self.name == "any") then
        return true
    end

    return self.interface.type_map[what]
end

function META:IsCompatible(type)
    if self:IsType(_G.type(type)) and (self.value == nil or self.value == type) then
        return true
    end

    return self:IsType(type)
end

function META:Type(...)
    local t = types.Create(...)
    t.analyzer = self.analyzer
    t:AttachNode(self:GetNode())
    return t
end

function META:Max(max)
    local t = self:Type(self.name, self.value)
    if max.value then
        t.max = max
    else
        t.value = nil
    end
    return t
end

function META:IsTruthy()
    if self.name == "any" then return true end

    if type(self.interface.truthy) == "table" then
        if self.value == nil then
            return self.interface.truthy._nil
        end
        return self.interface.truthy[self.value]
    end
    return self.interface.truthy
end

function META:Extend(t)
    local copy = self:Copy()

    for k,v in pairs(t.value) do
        if not copy.value[k] then
            copy:set(k,v)
        end
    end

    return copy
end

function META:BinaryOperator(op_node, b, node, env)
    assert(types.IsTypeObject(b))
    local a = self

    local op = op_node.value.value

    if op == "." or op == ":" then
        if b.get then
            return b:get(a, node, env)
        end
    end

    -- HACK
    if op == ".." or op == "^" then
        a,b = b,a
    end

    if env == "typesystem" then
        if op == "|" then
            return types.Fuse(a, b)
        elseif op == "extends" then
            return a:Extend(b)
        elseif op == "and" then
            return b and a
        elseif op == "or" then
            return b or a
        elseif b == false or b == nil then
            return false
        elseif op == ".." then
            local new = a:Copy()
            new.max = b
            return new
        end
    end

    if self.name == "..." then
        if a.values and a.values[1] then
            return self.values[1]:BinaryOperator(op_node, b, node, env)
        end
    end

    if b.name == "..." then
        if b.values and b.values[1] then
            return self:BinaryOperator(op_node, b.values[1], node, env)
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

        if (not b:IsType(arg) and ret ~= "last") then
            self:Error("no operator for `" .. tostring(b:GetReadableContent()) .. " " .. op .. " " .. tostring(a:GetReadableContent()) .. "`", op_node)
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

        if ret == "last" then
            if syntax.CompiledBinaryOperatorFunctions[op] then

                local ok, res = pcall(syntax.CompiledBinaryOperatorFunctions[op], b.value, a.value)
                if not ok then
                    self:Error(res)
                else
                    if res == b.value then
                        return b
                    elseif res == a.value then
                        return a
                    end
                end
            end

            return a + b
        end

        if syntax.CompiledBinaryOperatorFunctions[op] and a.value ~= nil and b.value ~= nil then
            local ok, res = pcall(syntax.CompiledBinaryOperatorFunctions[op], a.value, b.value)
            if not ok then
                self:Error(res)
            else
                return self:Type(ret, res)
            end
        end

        if op == "%" and a:IsType("number") and a:IsType("number") and a.value then
            local t = self:Type("number", 0)
            t.max = a:Copy()
            return t
        end

        return self:Type(ret)
    end

    self:Error("no operator for `" .. tostring(b) .. " " .. op .. " " .. tostring(a) .. "`", op_node)

    return self:Type("any")
end
function META:PrefixOperator(op_node)
    local op = op_node.value.value

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

    self:Error("invalid prefix operation " .. op .. " on " .. tostring(self), op_node)

    return self:Type("any")
end

function META:PostfixOperator(op_node)
    local op = op_node.value.value

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

function META:RemoveNonTruthy()
end


META.Error = Error

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

            self.trace = debug.traceback()

            if interface.init then
                for k,v in pairs(interface.init(self, ...)) do
                    self[k] = v
                end
            else
                self.value = ...
            end


            self.get = interface.get
            self.set = interface.set

            self.name = name

            return self
        end,
    }


    return registered[name].new
end

function types.IsType(name)
    if name == "table" or name == "list" then return false end

    return registered[name]
end

function types.Create(name, ...)
    assert(registered[name], "type " .. name .. " does not exist")
    return registered[name].new(...)
end

function types.OverloadFunction(a, b)
    a.overloads = a.overloads or {a}
    table.insert(a.overloads, b)

    table.sort(a.overloads, function(a, b) return #a.arguments > #b.arguments end)

    return a
end

function META:GetReturnTypes()
    return self.ret
end

function META:Serialize()
    return tostring(self)
end



function types.CallFunction(func, args)
    local errors = {}
    local found

    local overloads = func.overloads or func.types

    for _, func in ipairs(overloads or {func}) do
        local ok = true

        if overloads and func.arguments and #func.arguments ~= #args then
            ok = false
        end

        if func.arguments then
            for i, typ in ipairs(func.arguments) do
                if (not args[i] or not typ:IsType(args[i])) and not (typ.name == "any" or typ.name == "...") then
                    ok = false
                    table.insert(errors, {func = func, err = {"expected " .. tostring(typ) .. " to argument #"..i.." got " .. tostring(args[i])}})
                end
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

    if found.func then
        _G.self = found.analyzer
        local res = {pcall(found.func, unpack(args))}
        _G.self = nil

        if not res[1] then
            func:Error(res[2])
            return {func:Type("any")}
        end

        table.remove(res, 1)

        if not res[1] then
            res[1] = func:Type("nil")
        end

        return res
    end

    return found.ret or {func:Type("any")}
end

do
    local META = {}
    META.__index = META

    META.Error = Error

    types.fuse_meta = META

    local function invoke(self, name, ...)
        local types = {}
        local done = {}
        for _, type in ipairs(self.types) do
            local ret = type[name](type, ...)
            if ret ~= nil then
                for k,v in pairs(_G.type(ret) == "table" and ret.types or {ret}) do
                    if _G.type(v) ~= "table" or not done[v.name] then
                        table.insert(types, v)
                        if _G.type(v) == "table" then
                            done[v.name] = true
                        end
                    end
                end
            end
        end

        if types[1] then
            return setmetatable({types = types}, META)
        end
    end

    function META:get(key)
        local out
        for _, type in ipairs(self.types) do
            if not out then
                out = type:get(key)
            else
                out = out + type:get(key)
            end
        end
        return out
    end

    function META:set(key, val)
        for _, type in ipairs(self.types) do
            type:set(key, val)
        end
    end

    function META:Serialize()
        return self:__tostring()
    end

    function META:__tostring()
        local str = {}

        for i, type in ipairs(self.types) do
            str[i] = tostring(type)
        end

        return table.concat(str, " | ")
    end



    function META.__add(a, b)
        if not a:IsType(b) then
            return types.Fuse(a, b)
        end

        return a
    end

    function META:Type(...)
        return self.types[1]:Type(...)
    end

    function META:IsTruthy()
        for _, type in ipairs(self.types) do
            if type:IsTruthy() then
                return true
            end
        end
        return false
    end


    function META:GetReadableContent()
        return tostring(self)
    end

    function META:IsType(what)
        if type(what) == "table" then

            for _,v in ipairs(what:GetTypes()) do
                if self:IsType(v) then
                    return true
                end
            end
        end

        for _, type in ipairs(self.types) do
            if type:IsType(self) then
                return true
            end
        end

        return false
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

    function META:Copy()
        local copy = setmetatable({types = {}}, META)
        for i,v in ipairs(self.types) do
            copy.types[i] = v:Copy()
        end
        return copy
    end

    function META:RemoveNonTruthy()
        for i = #self.types, 1, -1 do
            local v = self.types[i]
            if not v:IsTruthy() then
                table.remove(self.types, i)
            end
        end
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
        ["or"] = {arg = "base", ret = "last"},
        ["and"] = {arg = "base", ret = "last"},
    },
    prefix = {
        ["not"] = "boolean",
    },
})


types.Register("any", {
    inherits = "base",
    truthy = true,
    get = function(self, key)
        return self:Type("any")
    end,
    set = function(self, key)
    end,
})

types.Register("string", {
    inherits = "base",
    truthy = true,
    get = function(self, key)
        if self.analyzer then
            local g = self.analyzer:GetValue("_G", "typesystem")
            if not g then
                if self.analyzer.Index then
                    g = self.analyzer:Index("_G")
                end
            end

            if g then
                if self.analyzer.Index then
                    local tbl = self.analyzer:Index("string")

                    if tbl and key then
                        return tbl:get(key)
                    end
                else
                    local tbl = self.analyzer:GetValue("string", "typesystem")

                    if tbl and key then
                        return tbl:get(key)
                    end
                end
            end
        end

        self:Error("index " .. tostring(key) .. " is not defined on the string type", key.node)

        return self:Type("any")
    end,
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
    init = function(self, value, structure)
        if structure then
            for key, val in pairs(structure) do
                if val[1] == "self" then
                    structure[key] = self
                end
            end
        end
        return {structure = structure, value = value}
    end,
    set = function(self, key, val, node, env)
        local hashed_key = type(key) == "string" and key or key.value

        if self.structure then
            local expected = {}

            for k,v in pairs(self.structure) do
                if key:IsCompatible(k) then
                    if not val:IsCompatible(v) or (v.value ~= nil and val.value ~= v.value) then
                        self:Error("invalid value " .. tostring(val) .. " expected " .. tostring(v), val.node)
                    end

                    if hashed_key then
                        self.value[hashed_key] = val
                    end

                    return
                end
                table.insert(expected, tostring(k))
            end

            self:Error("invalid key " .. tostring(key) .. (expected[1] and (" expected " .. table.concat(expected, " | ")) or ""), key.node)
        elseif self.value then
            if key.max then
                self.value[key] = val
            elseif hashed_key and val then
                self.value[hashed_key] = val
            end
        end
    end,
    get = function(self, key)
        local hashed_key = (type(key) == "string" or type(key) == "number") and key or key.value

        if self.structure then

            if hashed_key then
                if self.value and self.value[hashed_key] then
                    return self.value[hashed_key]
                elseif self.structure[hashed_key] then
                    return self.structure[hashed_key]
                end
            end

            local expected = {}

            for k,v in pairs(self.structure) do
                if key:IsCompatible(k) then
                    return v
                end

                table.insert(expected, tostring(k))
            end

            if self.index then
                return self:index(key)
            end

            self:Error("invalid key " .. tostring(key) .. " expected " .. table.concat(expected, " | "), key.node)
        end

        if hashed_key and self.value and self.value[hashed_key] then
            return self.value[hashed_key]
        end

        if self.value then
            for k,v in pairs(self.value) do

                if hashed_key then
                    local hashed_key2 = (type(k) == "string" or type(k) == "number") and k or k.value
                    if hashed_key2 == hashed_key then
                        return v
                    end
                elseif key:IsCompatible(k) then
                    return v
                end
            end
        end

        if self.index then
            return self:index(key)
        end

        return self:Type("any")
    end,
    tostring = function(self)
        if self.during_tostring then return "*self" end

        self.during_tostring = true
        local str = {"table"}
        if self.value then
            table.insert(str, " {")
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
        end

        local str = table.concat(str, " ")

        if #str > 20 then
            str = str:sub(1, 20) .. " ... }"
        end

        self.during_tostring = false
        return str
    end,
})

do
    local function check_index(self, key)
        if not key:IsType("number") then
            key:Error("cnnnot index " .. tostring(key) .. " on list")
        elseif self.length and key.value and key.value > self.length then
            key:Error("out of bounds " .. tostring(key))
        elseif key.value and key.value < 1 then
            key:Error("out of bounds " .. tostring(key))
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
        ["%"] = "number",
        ["^"] = "number",

        ["<"] = {arg = "number", ret = "boolean"},
        [">"] = {arg = "number", ret = "boolean"},
        ["<="] = {arg = "number", ret = "boolean"},
        [">="] = {arg = "number", ret = "boolean"},
    }
})

types.Register("...", {
    inherits = "base",
    init = function(self, ...)
        return {values = ...}
    end,
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

setmetatable(types, {
    __call = function(_, ...)
        return types.Create(...)
    end,
    __index = function(_, key)
        if registered[key] then
            return registered[key].new
        end
    end,
})

return types