local T = require("test.helpers")
local run = T.RunCode

it("should return a tuple with types", function()
    local analyzer = run([[
        local type test = function()
            return 1,2,3
        end

        local type a,b,c = test()
    ]])

    equal(1, analyzer:GetValue("a", "typesystem"):GetData())
    equal(2, analyzer:GetValue("b", "typesystem"):GetData())
    equal(3, analyzer:GetValue("c", "typesystem"):GetData())
end)

it("should be able to error", function()
    run([[
        local type test = function()
            error("test")
        end

        test()
    ]], "test")
end)

it("exclude type function should work", function()
    run([[
        type function Exclude(T, U)
            T:RemoveElement(U)
            return T
        end

        local a: Exclude<(1|2|3, 2)>

        type_assert(a, _ as 1|3)
    ]])

    run([[
        type function Exclude(T, U)
            T:RemoveElement(U)
            return T
        end

        local a: Exclude<(1|2|3, 2)>

        type_assert(a, _ as 11|31)
    ]], "expected 11 | 31 got 1 | 3")
end)

it("self referenced type tables", function()
    run[[
        local type a = {
            b = self,
        }
        type_assert(a, a.b)
    ]]
end)

it("next should work", function()
    run[[
        local t = {k = 1}
        local a = 1
        local k,v = next({k = 1})
        type_assert(k, nil as "k" | "k")
        type_assert(v, nil as 1 | 1)
    ]]
    run[[
        local k,v = next({foo = 1})
        type_assert(string.len(k), _ as 3 | 3)
        type_assert(v, _ as 1 | 1)
    ]]
end)

it("math.floor", function()
    run[[
        type_assert(math.floor(1.5), 1)
    ]]
end)

it("assert", function()
    run([[
        assert(1 == 2, "lol")
    ]],"lol")
end)

it("require should error when not finding a module", function()
    run([[require("adawdawddwaldwadwadawol")]], "unable to find module")
end)

it("load", function()
    run[[
        type_assert(assert(load("type_assert(1, 1) return 2"))(), 2)
    ]]

    run[[
        type_assert(assert(load("return " .. 2))(), 2)
    ]]
end)

it("rawset rawget", function()
    run[[
        local meta = {}
        meta.__index = meta

        local called = false
        function meta:__newindex(key: string, val: any)
            called = true
        end

        local self = setmetatable({}, meta)
        rawset(self, "lol", "LOL")
        type_assert(rawget(self, "lol"), "LOL")
        type_assert(called, false)
    ]]
end)

it("select", function()
    run[[
        type_assert(select("#", 1,2,3), 3)
    ]]
end)

it("parenthesis around vararg should work", function()
    run[[
        local a = select(2, 1,2,3)
        type_assert(a, 2)
        type_assert((select(2, 1,2,3)), 2)
    ]]
end)

it("varargs", function()
    run[[
    type test = function(...) end
    local a = {}
    a[1] = true
    a[2] = false
    test(test(a))

    ]]
end)

it("exlcude", function()
    run[[
        type function Exclude(T, U)
            T:RemoveElement(U)
            return T
        end

        local a: Exclude<(1|2|3, 2)>
        type_assert(a, _ as 1|3)
    ]]
end)

it("table.insert", function()
    run[[
        local a = {}
        a[1] = true
        a[2] = false
        table.insert(a, 1337)
        type_assert(a[3], 1337)
    ]]
end)
