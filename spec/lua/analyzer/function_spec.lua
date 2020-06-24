local T = require("spec.lua.helpers")
local run = T.RunCode

describe("function", function()
    it("arguments should work", function()
        local analyzer = run[[
            local function test(a,b,c)
                return a+b+c
            end
            local a = test(1,2,3)
        ]]

        assert.equal(6, analyzer:GetValue("a", "runtime"):GetData())
    end)

    it("arguments should get annotated", function()
        local analyzer = run[[
            local function test(a,b,c)
                return a+c
            end

            test(1,"",3)
        ]]

        local args = analyzer:GetValue("test", "runtime"):GetArguments()
        assert.equal(true, args:Get(1):IsType("number"))
        assert.equal(true, args:Get(2):IsType("string"))
        assert.equal(true, args:Get(3):IsType("number"))

        local rets = analyzer:GetValue("test", "runtime"):GetReturnTypes()
        assert.equal(true, rets:Get(1):IsType("number"))
    end)


    it("arguments and return types are volatile", function()
        local analyzer = run[[
            local function test(a)
                return a
            end

            test(1)
            test("")
        ]]

        local func = analyzer:GetValue("test", "runtime")

        local args = func:GetArguments()
        assert.equal(true, args:Get(1):IsType("number"))
        assert.equal(true, args:Get(1):IsType("string"))

        local rets = func:GetReturnTypes()
        assert.equal(true, rets:Get(1):IsType("number"))
        assert.equal(true, rets:Get(1):IsType("string"))
    end)

    it("which is not explicitly annotated should not dictate return values", function()
        local analyzer = run[[
            local function test(a)
                return a
            end

            test(1)

            local a = test(true)
        ]]

        local val = analyzer:GetValue("a", "runtime")
        assert.equal(true, val:IsType("boolean"))
        assert.equal(true, val:GetData())
        assert.equal(false, val:IsVolatile())
    end)

    it("which is explicitly annotated should error when the actual return value is different", function()
        run([[
            local function test(a)
                return a
            end

            local a: string = test(1)
        ]], "1.-is not the same type as string")
    end)

    it("which is explicitly annotated should error when the actual return value is unknown", function()
        run([[
            local function test(a: number): string
                return a
            end
        ]], "number is not the same type as string")
    end)

    it("call within a function shouldn't mess up collected return types", function()
        local analyzer = run[[
            local function b()
                (function() return 888 end)()
                return 1337
            end

            local c = b()
        ]]
        local c = analyzer:GetValue("c", "runtime")
        assert.equal(1337, c:GetData())
    end)

    it("arguments with any should work", function()
        run([[
            local function test(b: any, a: any)

            end

            test(123, "a")
        ]])
    end)

    it("self argument should be volatile", function()
        local analyzer = run([[
            local meta = {}
            function meta:Foo(b)

            end
            local a = meta.Foo
        ]])

        local self = analyzer:GetValue("a", "runtime"):GetArguments():Get(1)
        assert(self.volatile)
    end)

    it("arguments that are explicitly typed should error", function()
        run([[
            local function test(a: 1)

            end

            test(2)
        ]], "2 is not a subset of 1")

        run([[
            local function test(a: number)

            end

            test("a")
        ]], "\"a\" is not the same type as number")

        run([[
            local function test(a: number, b: 1)

            end

            test(5123, 2)
        ]], "2 is not a subset of 1")

        run([[
            local function test(b: 123, a: number)

            end

            test(123, "a")
        ]], "\"a\" is not the same type as number")
    end)

    it("arguments that are not explicitly typed should be volatile", function()
        do
            local analyzer = run[[
                local function test(a, b)
                    return 1337
                end

                test(1,"a")
            ]]

            local args = analyzer:GetValue("test", "runtime"):GetArguments()
            local a = args:Get(1)
            local b = args:Get(2)

            assert.equal("number", a.type)
            assert.equal(true, a.volatile)
            assert.equal(1, a.data)

            assert.equal("string", b.type)
            assert.equal(true, b.volatile)
            assert.equal("a", b.data)
        end

        do
            local analyzer = run[[
                local function test(a, b)
                    return 1337
                end

                test(1,"a")
                test("a",1)
            ]]

            local args = analyzer:GetValue("test", "runtime"):GetArguments()
            local a = args:Get(1)
            local b = args:Get(2)

            assert.equal(a:Serialize(), b:Serialize())
        end

        do
            local analyzer = run[[
                local function test(a, b)
                    return 1337
                end

                test(1,"a")
                test("a",1)
                test(4,4)
            ]]

            local args = analyzer:GetValue("test", "runtime"):GetArguments()
            local a = args:Get(1)
            local b = args:Get(2)

            assert.equal(a:Serialize(), b:Serialize())
        end


        local analyzer = run[[
            local function test(a, b)
                return 1337
            end

            test(1,2)
            test("awddwa",{})
        ]]
        local b = analyzer:GetValue("b", "runtime")
    end)

    it("https://github.com/teal-language/tl/blob/master/spec/lax/lax_spec.lua", function()
        local analyzer = run[[
            function f1()
                return { data = function () return 1, 2, 3 end }
            end

            function f2()
                local one, two, three
                local data = f1().data
                one, two, three = data()
                return one, two, three
            end

            local a,b,c = f2()
        ]]
        local a = analyzer:GetValue("a", "runtime")
        local b = analyzer:GetValue("b", "runtime")
        local c = analyzer:GetValue("c", "runtime")

        assert.equal(1, a:GetData())
        assert.equal(2, b:GetData())
        assert.equal(3, c:GetData())
    end)

    it("return type should work", function()
        local analyzer = run[[
            function foo(a: number):string return '' end
        ]]
    end)

    it("defining a type for a function should type the arguments", function()
        run[[
            local type test = function(number, string): 1

            function test(a, b)
                return 1
            end

            test(14, "asd")
        ]]

        run([[
            local type test = function(number, string): 1

            function test(a, b)
                return 1
            end

            test(true, 2)
        ]], "true is not the same type as number")
    end)

    it("calling a set should work", function()
        run[[
            type test = (function(boolean, boolean): number) | (function(boolean): string)

            local a = test(true, true)
            local b = test(true)

            type_assert(a, _ as number)
            type_assert(b, _ as string)
        ]]
    end)

    it("calling a set that does not contain a function should error", function()
        run([[
            type test = (function(boolean, boolean): number) | (function(boolean): string) | number

            test(true, true)
        ]], "set contains uncallable object number")
    end)

    it("pcall", function()
        run[[
            type pcall = function(cb: function, ...)
                return types.Object:new("boolean"), table.unpack(analyzer:Call(cb, types.Tuple:new({...})):GetData())
            end

            local ok, err = pcall(function()
                local a, b = 10.5, nil
                return a < b
            end)

            type_assert(ok, _ as boolean)
            type_assert(err, _ as boolean)
        ]]
    end)
end)