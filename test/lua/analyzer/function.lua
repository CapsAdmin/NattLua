local T = require("test.helpers")
local run = T.RunCode

test("arguments", function()
    local analyzer = run[[
        local function test(a,b,c)
            return a+b+c
        end
        local a = test(1,2,3)
    ]]

    equal(6, analyzer:GetEnvironmentValue("a", "runtime"):GetData())
end)

test("arguments should get annotated", function()
    local analyzer = run[[
        local function test(a,b,c)
            return a+c
        end

        test(1,"",3)
    ]]

    local args = analyzer:GetEnvironmentValue("test", "runtime"):GetArguments()

    equal("number", args:Get(1):GetType("number").Type)
    equal("string", args:Get(2):GetType("string").Type)
    equal("number", args:Get(3):GetType("number").Type)

    local rets = analyzer:GetEnvironmentValue("test", "runtime"):GetReturnTypes()
    equal("number", rets:Get(1).Type)
end)

test("arguments and return types are volatile", function()
    local analyzer = run[[
        local function test(a)
            return a
        end

        test(1)
        test("")
    ]]

    local func = analyzer:GetEnvironmentValue("test", "runtime")

    local args = func:GetArguments()
    equal(true, args:Get(1):HasType("number"))
    equal(true, args:Get(1):HasType("string"))

    local rets = func:GetReturnTypes()
    equal(true, rets:Get(1):HasType("number"))
    equal(true, rets:Get(1):HasType("string"))
end)

test("which is not explicitly annotated should not dictate return values", function()
    local analyzer = run[[
        local function test(a)
            return a
        end

        test(1)

        local a = test(true)
    ]]

    local val = analyzer:GetEnvironmentValue("a", "runtime")
    equal(true, val.Type == "symbol")
    equal(true, val:GetData())
end)

test("which is explicitly annotated should error when the actual return value is different", function()
    run([[
        local function test(a)
            return a
        end

        local a: string = test(1)
    ]], "1.-is not the same type as string")
end)

test("which is explicitly annotated should error when the actual return value is unknown", function()
    run([[
        local function test(a: number): string
            return a
        end
    ]], "number is not the same type as string")
end)

test("call within a function shouldn't mess up collected return types", function()
    local analyzer = run[[
        local function b()
            (function() return 888 end)()
            return 1337
        end

        local c = b()
    ]]
    local c = analyzer:GetEnvironmentValue("c", "runtime")
    equal(1337, c:GetData())
end)

test("arguments with any", function()
    run([[
        local function test(b: any, a: any)

        end

        test(123, "a")
    ]])
end)

test("self argument should be volatile", function()
    local analyzer = run([[
        local meta = {}
        function meta:Foo(b)

        end
        local a = meta.Foo
    ]])

    local self = analyzer:GetEnvironmentValue("a", "runtime"):GetArguments():Get(1):GetType("table")
    equal("table", self.Type)
end)

test("arguments that are explicitly typed should error", function()
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

test("arguments that are not explicitly typed should be volatile", function()
    do
        local analyzer = run[[
            local function test(a, b)
                return 1337
            end

            test(1,"a")
        ]]

        local args = analyzer:GetEnvironmentValue("test", "runtime"):GetArguments()
        local a = args:Get(1)
        local b = args:Get(2)

        equal("number", a:GetType("number").Type)
        equal(1, a:GetType("number").data)

        equal("string", b:GetType("string").Type)
        equal("a", b:GetType("string").data)
    end

    do
        local analyzer = run[[
            local function test(a, b)
                return 1337
            end

            test(1,"a")
            test("a",1)
        ]]

        local args = analyzer:GetEnvironmentValue("test", "runtime"):GetArguments()
        local a = args:Get(1)
        local b = args:Get(2)

        equal(a:GetSignature(), b:GetSignature())
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

        local args = analyzer:GetEnvironmentValue("test", "runtime"):GetArguments()
        local a = args:Get(1)
        local b = args:Get(2)

        equal(a:GetSignature(), b:GetSignature())
    end


    local analyzer = run[[
        local function test(a, b)
            return 1337
        end

        test(1,2)
        test("awddwa",{})
    ]]
    local b = analyzer:GetEnvironmentValue("b", "runtime")
end)

test("https://github.com/teal-language/tl/blob/master/spec/lax/lax_spec.lua", function()
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
    local a = analyzer:GetEnvironmentValue("a", "runtime")
    local b = analyzer:GetEnvironmentValue("b", "runtime")
    local c = analyzer:GetEnvironmentValue("c", "runtime")

    equal(1, a:GetData())
    equal(2, b:GetData())
    equal(3, c:GetData())
end)

test("return type", function()
    local analyzer = run[[
        function foo(a: number):string return '' end
    ]]
end)

test("defining a type for a function should type the arguments", function()
    run[[
        local type test = function(number, string): 1

        function test(a, b)
            return 1
        end

        test(14, "asd")
    ]]

    run([[
        local type test = function(a: number, b: string): 1

        function test(a, b)
            return 1
        end

        test(true, 2)
    ]], "true is not the same as number")
end)

test("calling a set", function()
    run[[
        local type test = (function(boolean, boolean): number) | (function(boolean): string)

        local a = test(true, true)
        local b = test(true)

        type_assert(a, _ as number)
        type_assert(b, _ as string)
    ]]
end)

test("calling a set that does not contain a function should error", function()
    run([[
        local type test = (function(boolean, boolean): number) | (function(boolean): string) | number

        test(true, true)
    ]], "set .- contains uncallable object number")
end)

test("pcall", function()
    run[[
        local type pcall = function(cb: any, ...)
            return types.Boolean, table.unpack(analyzer:Call(cb, types.Tuple({...})):GetData())
        end

        local ok, err = pcall(function()
            local a, b = 10.5, nil
            return a < b
        end)

        type_assert(ok, _ as boolean)
        type_assert(err, _ as boolean)
    ]]
end)
test("complex", function()
    run[[
        local function foo()
            return foo()
        end
        
        foo()

        type_assert_superset(foo, nil as (function():any))
    ]]
end)
test("lol", function()
    run[[
        do
            type x = boolean | number
        end

        local type c = x
        local a: c
        local type b = {foo = a as any}
        local c: function(a: number, b:number): b, b

        type_assert_superset(c, nil as function(_:number, _:number): {foo = any}, {foo = any})

        type x = nil
    ]]
end)

test("lol2", function()
    run[[
        local function test(a:number,b: number)
            return a + b
        end

        type_assert_superset(test, nil as function(_:number, _:number): number)
    ]]
end)

test("make sure analyzer return flags dont leak over to deferred calls", function()
    local foo = run([[
        local function bar() end
        bar()
        
        function foo()
            a = 1
            return true
        end
        
        return nil
    ]]):GetEnvironmentValue("foo", "runtime")
    
    equal(foo:GetReturnTypes():Get(1):GetData(), true)
end)

run[[
    local a = function()
        if maybe then
            -- the return value here sneaks into val
            return ""
        end
        
        -- val is "" | 1
        local val = (function() return 1 end)()
        
        type_assert(val, 1)

        return val
    end

    type_assert(a(), _ as 1 | "")
]]

run[[
    local x = (" "):rep(#tostring(_ as string))
    type_assert(x, _ as string)
]]

run[[
    local function foo()
        return "foo"
    end
    
    local function bar()
        return "bar"
    end
    
    local function genfunc(name)
        local f = name == "foo" and foo or bar
        return f
    end
    
    local f = genfunc("foo")
    type_assert(f(), "foo")
]]

run[[
    function faz(a)
        return foo(a + 1)
    end
    
    function bar(a)
        return faz(a + 1)
    end
    
    function foo(a)
        return bar(a + 1)
    end
    
    type_assert(foo(1), _ as any)
]]