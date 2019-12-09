local syntax = require("oh.syntax")
local types = {}

function types.GetSignature(obj)
    if type(obj) == "table" and obj.GetSignature then
        return obj:GetSignature()
    end

    return tostring(obj)
end

function types.IsType(obj, what)
    return getmetatable(obj) == types[what]
end

function types.GetObjectType(val)
    return getmetatable(val) == types.Object and val.type
end

function types.OverloadFunction(a, b)
    for _, keyval in ipairs(b.data.data) do
        a.data:Set(keyval.key, keyval.val)
    end
end

function types.IsPrimitiveType(val)
    return val == "string" or
    val == "number" or
    val == "boolean" or
    val == "true" or
    val == "false"
end

function types.IsTypeObject(obj)
    return types.GetType(obj) ~= nil
end

function types.GetType(val)
    local m = getmetatable(val)
    if m then
        if m == types.Set then
            return "set"
        elseif m == types.Tuple then
            return "tuple"
        elseif m == types.Object then
            return "object"
        elseif m == types.Dictionary then
            return "dictionary"
        end
    end
end

function types.SupersetOf(a, b)
    return a:SupersetOf(b)
end

function types.Union(a, b)
    if types.IsType(a, "Dictionary") and types.IsType(b, "Dictionary") then
        local copy = types.Dictionary:new({})

        for _, keyval in pairs(a.data) do
            copy:Set(keyval.key, keyval.val)
        end

        for _, keyval in pairs(b.data) do
            copy:Set(keyval.key, keyval.val)
        end

        return copy
    end
end

function types.CallFunction(obj, arguments)
    if obj.lua_function then
        _G.self = obj.analyzer
        local res = {pcall(obj.lua_function, unpack(arguments))}
        _G.self = nil

        if not res[1] then
            obj.analyzer:Error(obj.node, res[2])
            return {types.Object:new("any")}
        end

        table.remove(res, 1)

        if not res[1] then
            res[1] = types.Object:new("nil")
        end

        return res
    end

    local argument_tuple = types.Tuple:new(unpack(arguments))
    local return_tuple = obj:Call(argument_tuple)
    return return_tuple
end


function types.NewIndex(obj, key, val)

end

function types.Index(obj, key)

end


do
    local function merge_types(src, dst)
        for i,v in ipairs(dst) do
            if src[i] and src[i].type ~= "any" then
                src[i] = types.Set:new(src[i], v)
            else
                src[i] = dst[i]
            end
        end

        return src
    end

    function types.MergeFunctionArguments(obj, arg, argument_key)
        local data = obj.data:GetKeyVal(argument_key)

        if arg then
            data.key.data = merge_types(data.key.data, arg)
        end
    end

    function types.MergeFunctionReturns(obj, ret, argument_key)
        local data = obj.data:GetKeyVal(argument_key)

        if ret then
            data.val.data = merge_types(data.val.data, ret)
        end
    end
end


function types.BinaryOperator(op, l, r, env)
    assert(types.IsTypeObject(l))
    assert(types.IsTypeObject(r))
    if env == "typesystem" then
        if op == "|" then
            return types.Set:new(l, r)
        end
    end

    local b = r
    local a = l

    if op == "." or op == ":" then
        if b.Get then
            return b:Get(a, node, env) or types.Create("nil")
        end
    end

    -- HACK
    if op == ".." or op == "^" then
        a,b = b,a
    end

    if env == "typesystem" then
        if op == "extends" then
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

    if op == "==" and l:IsType("number") and r:IsType("number") and l.data and r.data then
        if l.max and l.max.data then
            return types.Object:new("boolean", r.data >= l.data and r.data <= l.max.data, true)
        end

        if r.max and r.max.data then
            return types.Object:new("boolean", l.data >= r.data and l.data <= r.max.data, true)
        end
    end

    if syntax.CompiledBinaryOperatorFunctions[op] and l.data ~= nil and r.data ~= nil then
        local lval = l.data
        local rval = r.data
        local type = l.type

        if types.GetType(l) == "tuple" then
            lval = l.data[1].data
            type = l.data[1].type
        end

        if types.GetType(r) == "tuple" then
            rval = r.data[1].data
        end

        local ok, res = pcall(syntax.CompiledBinaryOperatorFunctions[op], lval, rval)
        if not ok then
            l.analyzer:Error(l.node, res)
        else
            return types.Object:new(type, res)
        end
    end

    if op == "%" and a:IsType("number") and l:IsType("number") and l.data then
        local t = types.Object:new("number", 0)
        t.max = a:Copy()
        return t
    end

    if op == "==" and (l:IsType("any") or r:IsType("any")) then
        return types.Object:new("boolean")
    end

    -- todo
    if l.type == r.type then
        return types.Object:new(l.type)
    end

    error(" NYI " .. env .. ": "..tostring(l).." "..op.. " "..tostring(r))
end

do

    local Dictionary = {}
    Dictionary.__index = Dictionary

    function Dictionary:GetSignature()
        if self.supress then
            return "*self*"
        end
        self.supress = true

        if not self.data[1] then
            return "{}"
        end

        local s = {}

        for i, keyval in ipairs(self.data) do
            s[i] = keyval.key:GetSignature() .. "=" .. keyval.val:GetSignature()
        end
        self.supress = nil

        table.sort(s, function(a, b) return a > b end)

        return table.concat(s, "\n")
    end

    local level = 0
    function Dictionary:Serialize()
        if not self.data[1] then
            return "{}"
        end

        if self.supress then
            return "*self*"
        end
        self.supress = true

        local s = {}

        level = level + 1
        for i, keyval in ipairs(self.data) do
            s[i] = ("\t"):rep(level) .. tostring(keyval.key) .. " = " .. tostring(keyval.val)
        end
        level = level - 1

        self.supress = nil

        table.sort(s, function(a, b) return a > b end)

        return "{\n" .. table.concat(s, ",\n") .. "\n" .. ("\t"):rep(level) .. "}"
    end

    function Dictionary:__tostring()
        return (self:Serialize():gsub("%s+", " "))
    end

    function Dictionary:GetLength()
        return #self.data
    end

    function Dictionary:SupersetOf(sub)
        if self == sub then
            return true
        end

        for _, keyval in ipairs(self.data) do
            local val = sub:Get(keyval.key, true)

            if not val then
                if self:Serialize():find("function(*self*)", nil, true) then
                    print(keyval.key:GetSignature(), "!!")
                    print("====")
                    for k,v in pairs(sub.data) do print(k,v) end
                    print("====")
                    print("SIGNATURE:")
                    print(sub:GetSignature())
                    print(".")
                    print(sub.data[keyval.key:GetSignature()])
                end
                return false
            end

            if not types.SupersetOf(keyval.val, val) then
                return false
            end
        end


        return true
    end

    function Dictionary:Lock(b)
        self.locked = true
    end

    function Dictionary:Cast(val)
        if type(val) == "string" then
            return types.Object:new("string", val, true)
        elseif type(val) == "number" then
            return types.Object:new("number", val, true)
        end
        return val
    end

    function Dictionary:Set(key, val)
        key = self:Cast(key)
        val = self:Cast(val)

        if val == nil or val.type == "nil" then
            for i, keyval in ipairs(self.data) do
                if types.SupersetOf(key, keyval.key) then
                    table.remove(self.data, _)
                    return
                end
            end
            return
        end

        for _, keyval in ipairs(self.data) do
            if types.SupersetOf(key, keyval.key) and types.SupersetOf(val, keyval.val) then
                keyval.val = val
                return
            end
        end

        if not self.locked then
            table.insert(self.data, {key = key, val = val})
        end
    end

    function Dictionary:Get(key)
        key = self:Cast(key)

        local keyval = self:GetKeyVal(key)

        if not keyval and self.meta then
            local index = self.meta:Get("__index")
            if types.GetType(index) == "dictionary" then
                return index:Get(key)
            end
        end

        if keyval then
            return keyval.val
        end
    end

    function Dictionary:GetKeyVal(key)
        for _, keyval in ipairs(self.data) do
            if types.SupersetOf(key, keyval.key) then
                return keyval
            end
        end
    end

    function Dictionary:Copy()
        local copy = Dictionary:new({})

        for _, keyval in ipairs(self.data) do
            copy:Set(keyval.key, keyval.val)
        end

        return copy
    end

    function Dictionary:Extend(t)
        local copy = self:Copy()

        for _, keyval in ipairs(t.data) do
            if not copy:Get(keyval.key) then
                copy:Set(keyval.key, keyval.val)
            end
        end

        return copy
    end

    function Dictionary:new(data)
        local self = setmetatable({}, self)

        self.data = data

        if data and not data[1] and next(data) then
            print(data)
            assert("bad table for dictionary")
        end

        return self
    end

    types.Dictionary = Dictionary


end

do
    local Object = {}
    Object.__index = Object

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
        if type(self.data) == "table" then
            if self.data.GetLength then
                return self.data:GetLength()
            end

            return #self.data
        end

        return 0
    end

    function Object:Get(key)
        if type(self.data) ~= "table" or not self.data.Get then return end

        local val = self.data:Get(key)

        if not val and self.meta then
            local index = self.meta:Get("__index")
            if index.type == "table" then
                return index:Get(key)
            end
        end

        return val
    end

    function Object:Set(key, val)
        return self.data:Set(key, val)
    end

    function Object:Call(args)
        return self.data:Get(args)
    end

    function Object:GetArguments(argument_tuple)
        local val = self.data:GetKeyVal(argument_tuple)
        return val and val.key.data
    end

    function Object:GetReturnTypes(argument_tuple)
        local val = self.data:GetKeyVal(argument_tuple)
        return val and val.val.data
    end

    function Object:SupersetOf(sub)
        if types.IsType(sub, "Set") then
           return sub:Get(self) ~= nil
        end

        if types.IsType(sub, "Object") then
            if sub.type == "any" then
                return true
            end

            if self.type == sub.type then

                if self.const == true and sub.const == true then

                    if self.data == sub.data then
                        return true
                    end

                    if self.type == "number" and sub.type == "number" and types.IsType(self.data, "Tuple") then
                        local min = self:Get(1).data
                        local max = self:Get(2).data

                        if types.IsType(sub.data, "Tuple") then
                            if sub:Get(1) >= min and sub:Get(2) <= max then
                                return true
                            end
                        else
                            if sub.data >= min and sub.data <= max then
                                return true
                            end
                        end
                    end
                end

                -- self = number(1)
                -- sub = 1

                if self.data ~= nil and self.data == sub.data then
                    return true
                end

                if not sub.data or not self.data then
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

    function Object:__tostring()
        --return "「"..self.uid .. " 〉" .. self:GetSignature() .. "」"
        if types.IsType(self, "Tuple") then
            local a = self.data:Get(1)
            local b = self.data:Get(2)

            if types.IsType(a, "Tuple") then
                return tostring(a) .. " => " .. tostring(b)
            elseif types.IsType(a, "Object") then
                return "(" .. tostring(a) .. " .. " .. tostring(b) .. ")"
            end
        end

        if self.type == "function" then
            local str = {}
            for _, keyval in ipairs(self.data.data) do
                table.insert(str, "function(" .. tostring(keyval.key) .. "):" .. tostring(keyval.val))
            end
            return table.concat(str, " | ")
        end

        if self.const then
            if self.type == "string" then
                return ("%q"):format(self.data)
            end

            return tostring(self.data) .. (self.max and (".." .. self.max.data) or "")
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

    function Object:IsTruthy()
        return self.type ~= "nil" and self.type ~= "false" and self.data ~= false
    end

    function Object:RemoveNonTruthy()
        return self
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

    types.Object = Object
end

do
    local Tuple = {}
    Tuple.__index = Tuple

    function Tuple:GetSignature()
        local s = {}

        for i,v in ipairs(self.data) do
            s[i] = types.GetSignature(v)
        end

        return table.concat(s, " ")
    end

    function Tuple:GetLength()
        return #self.data
    end

    function Tuple:SupersetOf(sub)
        for i = 1, sub:GetLength() do
            if sub:Get(i).type ~= "any" and (not self:Get(i) or not self:Get(i):SupersetOf(sub:Get(i))) then
                return false
            end
        end

        return true
    end

    function Tuple:Get(key)
        return self.data[key]
    end

    function Tuple:Set(key, val)
        self.data[key] =  val
    end

    function Tuple:__tostring()
        local s = {}

        for i,v in ipairs(self.data) do
            s[i] = tostring(v)
        end

        return table.concat(s, ", ")
    end

    function Tuple:new(...)
        local self = setmetatable({}, self)

        self.data = {...}

        for i,v in ipairs(self.data) do
            assert(types.IsTypeObject(v))
        end

        return self
    end

    types.Tuple = Tuple
end

do
    local Set = {}
    Set.__index = Set

    function Set:GetSignature()
        local s = {}

        for _, v in pairs(self.data) do
            table.insert(s, types.GetSignature(v))
        end

        table.sort(s, function(a, b) return a < b end)

        return table.concat(s, "|")
    end

    function Set:__tostring()
        local s = {}
        for _, v in pairs(self.data) do
            table.insert(s, tostring(v))
        end

        table.sort(s, function(a, b) return a < b end)

        return table.concat(s, " | ")
    end

    function Set:AddElement(e)
        if types.GetType(e) == "set" then
            for _, e in pairs(e.data) do
                self:AddElement(e)
            end
            return self
        end

        self.data[types.GetSignature(e)] = e

        return self
    end

    function Set:GetLength()
        local len = 0
        for _, v in pairs(self.data) do
            len = len + 1
        end
        return len
    end

    function Set:RemoveElement(e)
        self.data[types.GetSignature(e)] = nil
    end

    function Set:Get(key, from_dictionary)
        if from_dictionary then
            for _, obj in pairs(self.data) do
                if obj.Get then
                    local val = obj:Get(key)
                    if val then
                        return val
                    end
                end
            end
        end

        return self.data[key:GetSignature()]
    end

    function Set:Set(key, val)
        return self:AddElement(val)
    end

    function Set:SupersetOf(sub)
        if types.IsType(sub, "Object") then
            return false
        end

        for _, e in pairs(self.data) do
            if not sub:Get(e) then
                return false
            end
        end

        return true
    end

    function Set:Union(set)
        local copy = self:Copy()

        for _, e in pairs(set.data) do
            copy:AddElement(e)
        end

        return copy
    end


    function Set:Intersect(set)
        local copy = types.Set:new()

        for _, e in pairs(self.data) do
            if set:Get(e) then
                copy:AddElement(e)
            end
        end

        return copy
    end


    function Set:Subtract(set)
        local copy = self:Copy()

        for _, e in pairs(self.data) do
            copy:RemoveElement(e)
        end

        return copy
    end

    function Set:Copy()
        local copy = Set:new()
        for _, e in pairs(self.data) do
            copy:AddElement(e)
        end
        return copy
    end


    function Set:new(...)
        local self = setmetatable({}, Set)

        self.data = {}

        for _, v in ipairs({...}) do
            self:AddElement(v)
        end

        return self
    end

    types.Set = Set
end

function types.Create(type, ...)
    if type == "nil" then
        return types.Object:new(type)
    elseif type == "any" then
        return types.Object:new(type)
    elseif type == "table" then
        local dict = types.Dictionary:new({})
        if ... then
            for k,v in pairs(...) do
                dict:Set(k,v)
            end
        end
        return dict
    elseif type == "boolean" then
        return types.Object:new("boolean", ...)
    elseif type == "..." then
        local values = ... or {}
        return types.Tuple:new(unpack(values))
    elseif type == "number" or type == "string" then
        return types.Object:new(type, ...)
    elseif type == "function" then
        local returns, arguments, lua_function = ...
        local dict = types.Dictionary:new({})
        dict:Set(types.Tuple:new(unpack(arguments)), types.Tuple:new(unpack(returns)))
        local obj = types.Object:new(type, dict)
        obj.lua_function = lua_function
        return obj
    elseif type == "list" then
        local values, len = ...
        local tup = types.Tuple:new(unpack(values or {}))
        if len then
            tup.max = len
        end
        return tup
    end
    error("NYI " .. type)
end

do return types end

do
    local Set = function(...) return types.Set:new(...) end
    local Tuple = function(...) return types.Tuple:new(...) end
    local Object = function(...) return types.Object:new(...) end
    local Dictionary = function(...) return types.Dictionary:new(...) end
    local N = function(n) return Object("number", n, true) end
    local S = function(n) return Object("string", n, true) end
    local O = Object

    assert(Set(S"a", S"b", S"a", S"a"):SupersetOf(Set(S"a", S"b", S"c")))
    assert(Set(S"c", S"d"):SupersetOf(Set(S"c", S"d")))
    assert(Set(S"c", S"d"):SupersetOf(Set(S"c", S"d")))
    assert(Set(S"a"):SupersetOf(Set(Set(S"a")))) -- should be false?
    assert(Set():SupersetOf(Set(S"a", S"b", S"c"))) -- should be false?
    assert(Set(N(1), N(4), N(5), N(9), N(13)):Intersect(Set(N(2), N(5), N(6), N(8), N(9))):GetSignature() == Set(N(5), N(9)):GetSignature())
    --print(Set(N(1), N(4), N(5), N(9), N(13)):Union(Set(N(2), N(5), N(6), N(8), N(9))))

    local A = Set(N(1),N(2),N(3))
    local B = Set(N(1),N(2),N(3),N(4))

    assert(B:GetSignature() == A:Union(B):GetSignature(), tostring(B) .. " should equal the union of "..tostring(A).." and " .. tostring(B))
    assert(B:GetLength() == 4)
    assert(A:SupersetOf(B))

    local yes = Object("boolean", true, true)
    local no = Object("boolean", false, true)
    local yes_and_no =  Set(yes, no)

    assert(types.SupersetOf(yes, yes_and_no), tostring(yes) .. "should be a subset of " .. tostring(yes_and_no))
    assert(types.SupersetOf(no, yes_and_no), tostring(no) .. " should be a subset of " .. tostring(yes_and_no))
    assert(not types.SupersetOf(yes_and_no, yes), tostring(yes_and_no) .. " is NOT a subset of " .. tostring(yes))
    assert(not types.SupersetOf(yes_and_no, no), tostring(yes_and_no) .. " is NOT a subset of " .. tostring(no))

    local tbl = Dictionary({})
    tbl:Set(yes_and_no, Object("boolean", false))
    tbl:Lock()
    tbl:Set(yes, yes)
    assert(tbl:Get(yes).data == true, " should be true")

    do
        local IAge = Dictionary({})
        IAge:Set(Object("string", "age", true), Object("number"))

        local IName = Dictionary({})
        IName:Set(Object("string", "name", true), Object("string"))
        IName:Set(Object("string", "magic", true), Object("string", "deadbeef", true))

        local function introduce(person)
            print(string.format("Hello, my name is %s and I am %s years old.", person:Get(Object("string", "name")), person:Get(Object("string", "age")) ))
        end

        local Human = types.Union(IAge, IName)
        Human:Lock()


        assert(IAge:SupersetOf(Human), "IAge should be a subset of Human")
        Human:Set(Object("string", "name", true), Object("string", "gunnar"))
        Human:Set(Object("string", "age", true), Object("number", 40))

        assert(Human:Get(Object("string", "name", true)).data == "gunnar")
        assert(Human:Get(Object("string", "age", true)).data == 40)

     --   print(Human:Get(Object("string", "magic")))
        Human:Set(Object("string", "magic"), Object("string", "lol"))
    end

    assert(Object("number", Tuple(N(-10), N(10)), true):SupersetOf(Object("number", 5, true)) == true, "5 should contain within -10..10")
    assert(Object("number", 5, true):SupersetOf(Object("number", Tuple(N(-10), N(10)), true)) == false, "5 should not contain -10..10")

    local overloads = Dictionary({})
    overloads:Set(Tuple(O"number", O"string"), Tuple(O"ROFL"))
    overloads:Set(Tuple(O"string", O"number"), Tuple(O"LOL"))
    local func = Object("function", overloads)
    assert(func:Call(Tuple(O"string", O"number")):GetSignature() == "LOL")
    assert(func:Call(Tuple(O("number", 5, true), O"string")):GetSignature() == "ROFL")


    assert(O("number"):SupersetOf(O("number", 5, true)) == false)
    assert(O("number", 5, true):SupersetOf(O("number")) == true)

    do
        local T = function()
            local obj = Object("table", Dictionary({}))

            return setmetatable({obj = obj}, {
                __newindex = function(_, key, val)
                    if type(key) == "string" then
                        key = Object("string", key, true)
                    elseif type(key) == "number" then
                        key = Object("number", key, true)
                    end

                    if val == _ then
                        val = obj
                    end

                    obj:Set(key, val)
                end,
                __index = function(_, key)
                    return obj:Get(S(key))
                end,
            })
        end

        local function F(overloads)
            local dict = Dictionary({})
            for k,v in pairs(overloads) do
                dict:Set(k,v)
            end
            return Object("function", dict)
        end

        local tbl = T()
        tbl.test = N(1)

        local meta = T()
        meta.__index = meta
        meta.__add = F({
            [O"string"] = O"self+string",
            [O"number"] = O"self+number",
        })

        tbl.meta = meta.obj

        function tbl:BinaryOperator(operator, value)
            if self.meta then
                local func = self.meta:Get(operator)
                if func then
                    return func:Call(value)
                end

                return nil, "the metatable does not have the " .. tostring(operator) .. " assigned"
            end
        end

        print(tbl:BinaryOperator(S"__add", N(1)))
    end

    --print(O("function", Tuple(Tuple(O"number", O"string"), Tuple(O"ROFL")), true):Call())
end