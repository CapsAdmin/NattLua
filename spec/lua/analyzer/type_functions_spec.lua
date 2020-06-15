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
            TPRINT(a)
        ]]
    end)

    pending("what", function()
        run[=[
            local a = 1
            function b(lol: number)
                if lol == 1 then return "foo" end
                return lol + 4, true
            end
            local d = b(2)
            local d = b(a)

            type hm = {
                a = boolean | nil,
                Foo = (function(self, number, string):nil) | nil
            }
            local lol: hm = {
                a = nil,
                Foo = nil
            }
            TPRINT(hm, "!!")

            lol.a = true

            function lol:Foo(foo, bar)
                local a = self.a
            end

            --local lol: string[] = {}

            --local a = table.concat(lol)
        ]=]
    end)

    pending("lists should work", function()
        local analyzer = run([[
            type Array = function(T, L)
                return types.Create("list", {type = T, values = {}, length = L.data})
            end

            local list: Array<number, 3> = {1, 2, 3}
        ]])
        print(analyzer:GetValue("list", "runtime"))
    end)

    it("next should work", function()
        run[[
            local t = {k = 1}
            local a = 1
            TPRINT(t.k, "!!!")
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
end)