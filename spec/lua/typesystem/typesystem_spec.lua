local types = require("oh.typesystem.types")
types.Initialize()

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

    return ret
end


local Set = function(...) return types.Set:new(cast(...)) end
local Tuple = function(...) return types.Tuple:new({...}) end

local Dictionary = function(...) return types.Dictionary:new(...) end
local N = function(n) return Object("number", n, true) end
local S = function(n) return Object("string", n, true) end
local O = Object

describe("typesystem", function()
    it("set should not contain duplicates", function()
        assert.equal(Set("a", "b", "a", "a"):Serialize(), Set("a", "b"):Serialize())
    end)

    it("smaller set should fit in larger set", function()
        assert(Set("a", "b", "c"):SupersetOf(Set("a", "b", "a", "a")))
        assert(Set("a", "b", "c"):SupersetOf(Tuple(Set("a", "b", "a", "a"))))
        assert(Tuple(Set("a", "b", "c")):SupersetOf(Tuple(Set("a", "b", "a", "a"))))
        assert(Tuple(Set("a", "b", "c")):SupersetOf(Set("a", "b", "a", "a")))

        assert(Set("c", "d"):SupersetOf(Set("c", "d")))
        assert(Set("a"):SupersetOf(Set(Set("a")))) -- should be false?
        assert(Set("a", "b", "c"):SupersetOf(Set())) -- should be false?
    end)

    it("set intersection should work", function()
        assert.equal(Set(1, 4, 5, 9, 13):Intersect(Set(2, 5, 6, 8, 9)):GetSignature(), Set(5, 9):GetSignature())
    end)

    local A = Set(N(1),N(2),N(3))
    local B = Set(N(1),N(2),N(3),N(4))

    it(tostring(B) .. " should equal the union of "..tostring(A).." and " .. tostring(B), function()
        assert.equal(B:GetSignature(), A:Union(B):GetSignature())
        assert.equal(4, B:GetLength())
        assert(B:SupersetOf(A))

    end)


    local yes = Object("boolean", true, true)
    local no = Object("boolean", false, true)
    local yes_and_no =  Set(yes, no)

    it(tostring(yes) .. " should be a subset of " .. tostring(yes_and_no), function()
        assert(yes:SupersetOf(yes_and_no) == false)
    end)

    it(tostring(no) .. "  should be a subset of " .. tostring(yes_and_no), function()
        assert(no:SupersetOf(yes_and_no) == false)
    end)

    it(tostring(yes_and_no) .. " is NOT a subset of " .. tostring(yes), function()
        assert(yes_and_no:SupersetOf(yes))
    end)

    it(tostring(yes_and_no) .. " is NOT a subset of " .. tostring(no), function()
        assert(yes_and_no:SupersetOf(no))
    end)


    pending("dictionary should be able to lock", function()
        local tbl = Dictionary({})
        tbl:Set(yes_and_no, Object("boolean", false))
        tbl:Lock(true)
        local what = tbl:Get(yes)
        assert(what.data == false, " should be false")
    end)

    pending("dictionary should be able to unlock", function()
        local tbl = Dictionary({})
        tbl:Set(yes_and_no, Object("boolean", false))
        tbl:Lock(false)
        tbl:Set(yes, yes, "typesystem")
        assert(tbl:Get(yes).data == true, " should be true")
    end)

end)

do
    do
        local IAge = Dictionary({})
        IAge:Set(Object("string", "age", true), Object("number"))

        local IName = Dictionary({})
        IName:Set(Object("string", "name", true), Object("string"))
        IName:Set(Object("string", "magic", true), Object("string", "deadbeef", true))

        local function introduce(person)
            io.write(string.format("Hello, my name is %s and I am %s years old.", person:Get(Object("string", "name")), person:Get(Object("string", "age")) ),"\n")
        end

        local Human = IAge:Union(IName)
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

    assert(assert(overloads:Call(Tuple(O"string", O"number"))):GetSignature() == "LOL")
    assert(assert(overloads:Call(Tuple(N(5), O"string"))):GetSignature() == "ROFL")

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