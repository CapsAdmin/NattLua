local T = require("test.helpers")
local run = T.RunCode

test("declaring base types", function()
    run[[
        local type Symbol = function(T: any)
            return types.Symbol(loadstring("return " .. T.node.value.value)(), true)
        end

        local type Nil = Symbol(nil)
        local type True = Symbol(true)
        local type False = Symbol(false)
        local type Boolean = True | False
        local type Number = -inf .. inf | nan
        local type String = $".-"
        local type Table = {[Number | Boolean | String | self] = Number | Boolean | String | Nil | self}
        local type Any = Number | Boolean | String | Nil | Table

        local str: String = "asdasdawd"
        local b: Boolean = true
        local b: Boolean = false

        local tbl: Table = {
            foo1 = true,
            bar = false,
            asdf = "asdf",
            [{foo2 = "bar"}] = "aaaaa",
            [{foo3 = "bar"}] = {[{1}] = {}},
        }

        local type Foo = Symbol("asdf")
        type_assert<(Foo == "asdf", false)>
    ]]
end)

test("comment types", function()
    run([=[
        -- local function foo(str--[[#: string]], idx--[[#: number]], msg--[[#: string]])

        local function foo(str, idx, msg)
            local a = arg:sub(1,2)

            return a
        end

        function bar()
            foo(4, {}, true)
        end

        --print(foo(1))
    ]=], "4 is not the same type as string")
end)

test("runtime reassignment", function()
    local v = run[[
        local a = 1
        do
            a = 2
        end
    ]]:GetValue("a", "runtime")

    equal(v:GetData(), 2)

    local v = run[[
        local a = 1
        if true then
            a = 2
        end
    ]]:GetValue("a", "runtime")

    equal(v:GetData(), 2)
end)


test("type_assert works", function()
    run("type_assert(1, 2)", "expected.-2 got 1")
    run("type_assert(nil as 1|2, 1)", "expected.-1")

    run"type_assert(not true, false)"
    run"type_assert(not 1, false)"
    run"type_assert(nil==nil, true)"
end)

test("runtime scopes", function()
    local v = run("local a = 1"):GetValue("a", "runtime")
    equal(true, v.Type == "number")
end)

test("comment types", function()
    run([=[
        --[[#local type a = 1]]
        type_assert(a, 1)
    ]=])
end)

test("default declaration is literal", function()
    local analyzer = run([[
        local a = 1
        local t = {k = 1}
        local b = t.k
    ]])
    assert(analyzer:GetValue("a", "runtime"):IsLiteral())
    assert(analyzer:GetValue("b", "runtime"):IsLiteral())
end)

test("branching", function()
    run([[
        type a = {}

        if not a then
            -- shouldn't reach
            type_assert(1, 2)
        else
            type_assert(1, 1)
        end
    ]])

    run([[
        type a = {}
        if not a then
            -- shouldn't reach
            type_assert(1, 2)
        end
    ]])
end)

test("runtime block scopes", function()

    local analyzer = run("do local a = 1 end")
    equal(nil, analyzer:GetValue("a", "runtime"))
    equal(1, analyzer:GetScope().children[1].upvalues.runtime.map.a.data:GetData()) -- TODO: awkward access

    local v = run[[
        local a = 1
        do
            local a = 2
        end
    ]]:GetValue("a", "runtime")

    equal(v:GetData(), 1)
end)

test("typesystem differs from runtime", function()
    local analyzer = run[[
        local a = 1
        local type a = 2
    ]]

    equal(analyzer:GetValue("a", "runtime"):GetData(), 1)
    equal(analyzer:GetValue("a", "typesystem"):GetData(), 2)
end)

test("global types", function()
    local analyzer = run[[
        do
            type a = 2
        end
        local b: a
    ]]

    equal(2, analyzer:GetValue("b", "runtime"):GetData())
end)

test("constant types", function()
    local analyzer = run[[
        local a: 1
        local b: number
    ]]

    equal(true, analyzer:GetValue("a", "runtime"):IsLiteral())
    equal(false, analyzer:GetValue("b", "runtime"):IsLiteral())
end)

-- literal + vague = vague
test("1 + number = number", function()
    local analyzer = run[[
        local a: 1
        local b: number
        local c = a + b
    ]]

    local v = analyzer:GetValue("c", "runtime")
    equal(true, v.Type == ("number"))
    equal(false, v:IsLiteral())
end)

test("1 + 2 = 3", function()
    local analyzer = run[[
        local a = 1
        local b = 2
        local c = a + b
    ]]

    local v = analyzer:GetValue("c", "runtime")
    equal(true, v.Type == ("number"))
    equal(3, v:GetData())
end)

test("function return value", function()
    local analyzer = run[[
        local function test()
            return 1+2+3
        end
        local a = test()
    ]]

    local v = analyzer:GetValue("a", "runtime")
    equal(6, v:GetData())
end)

test("multiple function return values", function()
    local analyzer = run[[
        local function test()
            return 1,2,3
        end
        local a,b,c = test()
    ]]

    equal(1, analyzer:GetValue("a", "runtime"):GetData())
    equal(2, analyzer:GetValue("b", "runtime"):GetData())
    equal(3, analyzer:GetValue("c", "runtime"):GetData())
end)


test("scopes shouldn't leak", function()
    local analyzer = run[[
        local a = {}
        function a:test(a, b)
            return nil, a+b
        end
        local _, a = a:test(1, 2)
    ]]

    equal(3, analyzer:GetValue("a", "runtime"):GetData())
end)

test("explicitly annotated variables need to be set properly", function()
    local analyzer = run[[
        local a: number | string = 1
    ]]
end)

test("functions can modify parent scope", function()
    local analyzer = run[[
        local a = 1
        local c = a
        local function test()
            a = 2
        end
        test()
    ]]

    equal(2, analyzer:GetValue("a", "runtime"):GetData())
    equal(1, analyzer:GetValue("c", "runtime"):GetData())
end)

test("uncalled functions should be called", function()
    local analyzer = run[[
        local lib = {}

        function lib.foo1(a, b)
            return lib.foo2(a, b)
        end

        function lib.main()
            return lib.foo1(1, 2)
        end

        function lib.foo2(a, b)
            return a + b
        end
    ]]
    local lib = analyzer:GetValue("lib", "runtime")

    equal("number", lib:Get("foo1"):GetArguments():Get(1):GetType("number").Type)
    equal("number", lib:Get("foo1"):GetArguments():Get(2):GetType("number").Type)
    equal("number", lib:Get("foo1"):GetReturnTypes():Get(1).Type)

    equal("number", lib:Get("foo2"):GetArguments():Get(1):GetType("number").Type)
    equal("number", lib:Get("foo2"):GetArguments():Get(2):GetType("number").Type)
    equal("number", lib:Get("foo2"):GetReturnTypes():Get(1):GetType("number").Type)
end)

test("should convert binary numbers to numbers", function()
    local analyzer = run[[
        local a = 0b01
    ]]
    equal(1, analyzer:GetValue("a", "runtime"):GetData())
end)

test("undefined types should error", function()
    run([[local a: ASDF = true]], "cannot find value ASDF")
end)

test("type functions should return a tuple with types", function()
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

test("type should be able to error", function()
    run([[
        local type test = function()
            error("test")
        end

        test()
    ]], "test")
end)

test("exclude type function", function()
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

test("parenthesis around varargs should only return the first value in the tuple", function()
    run[[
        local function s(...) return ... end
        local a,b,c = (s(1, 2, 3))
        type_assert(a, 1)
        type_assert(b, nil)
        type_assert(c, nil)
    ]]
end)

test("type function varargs", function()
    run[[
        local lol = function(...)
            local a,b,c = ...
            type_assert(a, 1)
            type_assert(b, 2)
            type_assert(c, 3)
        end

        local function lol2(...)
            lol(...)
        end

        lol2(1,2,3)
    ]]
end)