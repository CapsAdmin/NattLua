local T = require("spec.lua.helpers")
local run = T.RunCode

describe("varargs", function()
    it("a", function()
        run[[
            local function test(...)

            end

            test({})
        ]]
    end)

    it("vararg", function()
        run[[
            local function test(...)
                local a,b,c = ...
                return a+b+c
            end

            type_assert(test(test(1,2,3), test(1,2,3), test(1,2,3)), 18)
        ]]
    end)


    it("smoke", function()
        run[[
            local function test()
                return 1,2
            end

            local a,b,c = test(), 3
            assert_type(a, 1)
            assert_type(b, 3)
            assert_type(c, nil)
        ]]

        run[[
            local function test(...)
                return 1,2,...
            end

            local a,b,c = test(3)

            type_assert(a,1)
            type_assert(b,2)
            type_assert(c,3)
        ]]
    end)

    it("vararg in table", function()
        run[[
            local function test(...)
                local a = {...}
                type_assert(a[1], 1)
                type_assert(a[2], 2)
                type_assert(a[3], 3)
            end

            test(1,2,3)
        ]]
    end)

    it("var arg in table and return", function()
        run[[
            local a,b,c = test(1,2,3)

            local function test(...)
                local a = {...}
                return a[1], a[2], a[3]
            end

            local a,b,c = test(10,20,30)
            type_assert(a, 10)
            type_assert(b, 20)
            type_assert(c, 30)
        ]]
    end)

    it("asadawd", function()
        run[[
            local function test(...)
                return 1,2,3, ...
            end

            local A, B, C, D = test(), 4

            type_assert(A, 1)
            type_assert(B, 4)
            type_assert(C, nil)
            type_assert(D, nil)
        ]]
    end)

end)