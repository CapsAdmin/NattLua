local types = require("oh.typesystem")

do
    local Object = function(...) return types.Object:new(...) end

    local function cast(...)
        local ret = {}
        for i = 1, select("#", ...) do
            local v = select(i, ...)
            local t = type(v)
            if t == "number" or t == "string" or t == "boolean" then
                ret[i] = Object(t, v, true)
            else
                ret[i] = v
            end
        end
        return unpack(ret)
    end


    local Set = function(...) return types.Set:new(cast(...)) end
    local Tuple = function(...) return types.Tuple:new(...) end

    local Dictionary = function(...) return types.Dictionary:new(...) end
    local N = function(n) return Object("number", n, true) end
    local S = function(n) return Object("string", n, true) end
    local O = Object

    assert(Set("a", "b", "a", "a"):Serialize() == Set("a", "b"):Serialize())
    assert(Set("a", "b", "c"):SupersetOf(Set("a", "b", "a", "a")))
    assert(Set("c", "d"):SupersetOf(Set("c", "d")))
    assert(Set("c", "d"):SupersetOf(Set("c", "d")))
    assert(Set("a"):SupersetOf(Set(Set("a")))) -- should be false?
    assert(Set("a", "b", "c"):SupersetOf(Set())) -- should be false?
    assert(Set(1, 4, 5, 9, 13):Intersect(Set(2, 5, 6, 8, 9)):GetSignature() == Set(5, 9):GetSignature())

    local A = Set(N(1),N(2),N(3))
    local B = Set(N(1),N(2),N(3),N(4))

    assert(B:GetSignature() == A:Union(B):GetSignature(), tostring(B) .. " should equal the union of "..tostring(A).." and " .. tostring(B))
    assert(B:GetLength() == 4)
    assert(B:SupersetOf(A))

    local yes = Object("boolean", true, true)
    local no = Object("boolean", false, true)
    local yes_and_no =  Set(yes, no)

    assert(yes:SupersetOf(yes_and_no), tostring(yes) .. "should be a subset of " .. tostring(yes_and_no))
    assert(no:SupersetOf(yes_and_no), tostring(no) .. " should be a subset of " .. tostring(yes_and_no))

    assert(yes_and_no:SupersetOf(yes), tostring(yes_and_no) .. " is NOT a subset of " .. tostring(yes))
    assert(yes_and_no:SupersetOf(no), tostring(yes_and_no) .. " is NOT a subset of " .. tostring(no))

    local tbl = Dictionary({})
    tbl:Set(yes_and_no, Object("boolean", false))
    tbl:Lock(true)
    tbl:Set(yes, yes)
    assert(tbl:Get(yes).data == false, " should be false")

    local tbl = Dictionary({})
    tbl:Set(yes_and_no, Object("boolean", false))
    tbl:Lock(false)
    tbl:Set(yes, yes, "typesystem")
    assert(tbl:Get(yes).data == true, " should be true")

    do
        local IAge = Dictionary({})
        IAge:Set(Object("string", "age", true), Object("number"))

        local IName = Dictionary({})
        IName:Set(Object("string", "name", true), Object("string"))
        IName:Set(Object("string", "magic", true), Object("string", "deadbeef", true))

        local function introduce(person)
            io.write(string.format("Hello, my name is %s and I am %s years old.", person:Get(Object("string", "name")), person:Get(Object("string", "age")) ),"\n")
        end

        local Human = types.Union(IAge, IName)
        Human:Lock()


        assert(IAge:SupersetOf(Human), "IAge should be a subset of Human")
        Human:Set(Object("string", "name", true), Object("string", "gunnar"))
        Human:Set(Object("string", "age", true), Object("number", 40))

        assert(Human:Get(Object("string", "name", true)).data == "gunnar")
        assert(Human:Get(Object("string", "age", true)).data == 40)

        Human:Set(Object("string", "magic"), Object("string", "lol"))
    end

    assert(N(-10):Max(N(10)):SupersetOf(N(5)) == true, "5 should contain within -10..10")
    assert(N(5):SupersetOf(N(-10):Max(N(10))) == false, "5 should not contain -10..10")

    local overloads = Set(Object("function", {
        arg = Tuple(O"number", O"string"),
        ret = Tuple(O"ROFL"),
    }), Object("function", {
        arg = Tuple(O"string", O"number"),
        ret = Tuple(O"LOL"),
    }))

    assert(Tuple(O"string", O"number"):SupersetOf(Tuple(O"number", O"string")) == false)
    assert(Tuple(O"number", O"string"):SupersetOf(Tuple(O"number", O"string")) == true)

    assert(overloads:Call(Tuple(O"string", O"number")):GetSignature() == "LOL")
    assert(overloads:Call(Tuple(N(5), O"string")):GetSignature() == "ROFL")

    assert(O("number"):SupersetOf(N(5)) == true)
    assert(N(5):SupersetOf(O("number")) == true)

    do return end

    -- wip

    do
        local T = function()
            local obj = Object("table", Dictionary({}))

            return setmetatable({obj = obj}, {
                __newindex = function(_, key, val)
                    if type(key) == "string" then
                        key = S(key)
                    elseif type(key) == "number" then
                        key = N(key)
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
            local ret = Set()
            for k,v in pairs(ret) do
                ret:AddElement(Object("function", {arg = k, ret = v}))
            end
            return ret
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

        io.write(tbl:BinaryOperator(S"__add", N(1)))
    end

    --print(O("function", Tuple(Tuple(O"number", O"string"), Tuple(O"ROFL")), true):Call())
end