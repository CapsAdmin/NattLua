local T = require("spec.lua.helpers")
local run = T.RunCode

describe("type functions", function()

    it("should return a tuple with types", function()
        local analyzer = run([[
            local type test = function()
                return 1,2,3
            end

            local type a,b,c = test()
        ]])

        assert.equal(1, analyzer:GetValue("a", "typesystem"):GetData())
        assert.equal(2, analyzer:GetValue("b", "typesystem"):GetData())
        assert.equal(3, analyzer:GetValue("c", "typesystem"):GetData())
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
            type Exclude = function(T, U)
                T:RemoveElement(U)
                return T
            end

            local a: Exclude<1|2|3, 2>

            type_assert(a, _ as 1|3)
        ]])

        run([[
            type Exclude = function(T, U)
                T:RemoveElement(U)
                return T
            end

            local a: Exclude<1|2|3, 2>

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
            type_assert(k, nil as "k")
            type_assert(v, nil as 1)
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
end)