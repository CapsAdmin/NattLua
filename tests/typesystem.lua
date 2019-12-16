local types = require("oh.typesystem")

do
    local Set = function(...) return types.Set:new(...) end
    local Tuple = function(...) return types.Tuple:new(...) end
    local Object = function(...) return types.Object:new(...) end
    local Dictionary = function(...) return types.Dictionary:new(...) end
    local N = function(n) return Object("number", n, true) end
    local S = function(n) return Object("string", n, true) end
    local O = Object

    assert(Set(S"a", S"b", S"a", S"a"):Serialize() == Set(S"a", S"b"):Serialize())
    assert(Set(S"a", S"b", S"c"):SupersetOf(Set(S"a", S"b", S"a", S"a")))
    assert(Set(S"c", S"d"):SupersetOf(Set(S"c", S"d")))
    assert(Set(S"c", S"d"):SupersetOf(Set(S"c", S"d")))
    assert(Set(S"a"):SupersetOf(Set(Set(S"a")))) -- should be false?
    assert(Set(S"a", S"b", S"c"):SupersetOf(Set())) -- should be false?
    assert(Set(N(1), N(4), N(5), N(9), N(13)):Intersect(Set(N(2), N(5), N(6), N(8), N(9))):GetSignature() == Set(N(5), N(9)):GetSignature())

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

        io.write(tbl:BinaryOperator(S"__add", N(1)))
    end

    --print(O("function", Tuple(Tuple(O"number", O"string"), Tuple(O"ROFL")), true):Call())
end