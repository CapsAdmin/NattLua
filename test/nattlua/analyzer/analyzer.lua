local T = require("test.helpers")
local R = T.RunCode
local E = T.RunCode

-- check that type assert works
E("type_assert(1, 2)", "expected.-2 got 1")
E("type_assert(nil as 1|2, 1)", "expected.-1")
E("type_assert<|string, number|>", "expected number got string")

R"type_assert(not true, false)"
R"type_assert(not 1, false)"
R"type_assert(nil == nil, true)"

test("declaring base types", function()
    R[[
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
        type_assert<|Foo == "asdf", false|>
    ]]
end)

test("escape comments", function()
    R[=[
        local a = --[[# 1  ^ ]] --[[# -1]] * 3 --[[# * 1]]
        local b = 1 ^ -1 * 3 + 1 * 1
        
        type_expect(a, b)
    ]=]

    R([=[
        local function foo(
            a --[[#: string]], 
            b --[[#: number]], 
            c --[[#: string]]) 
        end
         
        type_assert<|argument_type<|foo, 1|>, string|>
        type_assert<|argument_type<|foo, 2|>, number|>
        type_assert<|argument_type<|foo, 3|>, string|>
    ]=])

    R[=[
        --[[# local type a = 1 ]]
        type_assert(a, 1)
    ]=]
end)

test("runtime scopes", function()
    local v = R("local a = 1"):GetLocalOrEnvironmentValue("a", "runtime")
    equal(true, v.Type == "number")
end)

test("default declaration is literal", function()
    R([[
        local a = 1
        local t = {k = 1}
        local b = t.k

        type_assert_literal<|a|>
        type_assert_literal<|b|>
    ]])
end)

test("runtime block scopes", function()

    local analyzer, syntax_tree = R("do local a = 1 end")
    equal(false, (syntax_tree.environments.runtime:Get("a")))
    equal(1, analyzer:GetScope().children[1].upvalues.runtime.map.a.data:GetData()) -- TODO: awkward access

    local v = R[[
        local a = 1
        do
            local a = 2
        end
    ]]:GetLocalOrEnvironmentValue("a", "runtime")

    equal(v:GetData(), 1)
end)

test("typesystem differs from runtime", function()
    local analyzer = R[[
        local a = 1
        local type a = 2
    ]]

    equal(analyzer:GetLocalOrEnvironmentValue("a", "runtime"):GetData(), 1)
    equal(analyzer:GetLocalOrEnvironmentValue("a", "typesystem"):GetData(), 2)
end)

test("global types", function()
    local analyzer = R[[
        do
            type a = 2
        end
        local b: a
        type a = nil
    ]]

    equal(2, analyzer:GetLocalOrEnvironmentValue("b", "runtime"):GetData())
end)

test("constant types", function()
    local analyzer = R[[
        local a: 1
        local b: number
    ]]

    equal(true, analyzer:GetLocalOrEnvironmentValue("a", "runtime"):IsLiteral())
    equal(false, analyzer:GetLocalOrEnvironmentValue("b", "runtime"):IsLiteral())
end)

-- literal + vague = vague
test("1 + number = number", function()
    local analyzer = R[[
        local a: 1
        local b: number
        local c = a + b
    ]]

    local v = analyzer:GetLocalOrEnvironmentValue("c", "runtime")
    equal(true, v.Type == ("number"))
    equal(false, v:IsLiteral())
end)

test("1 + 2 = 3", function()
    local analyzer = R[[
        local a = 1
        local b = 2
        local c = a + b
    ]]

    local v = analyzer:GetLocalOrEnvironmentValue("c", "runtime")
    equal(true, v.Type == ("number"))
    equal(3, v:GetData())
end)

test("function return value", function()
    local analyzer = R[[
        local function test()
            return 1+2+3
        end
        local a = test()
    ]]

    local v = analyzer:GetLocalOrEnvironmentValue("a", "runtime")
    equal(6, v:GetData())
end)

test("multiple function return values", function()
    local analyzer = R[[
        local function test()
            return 1,2,3
        end
        local a,b,c = test()
    ]]

    equal(1, analyzer:GetLocalOrEnvironmentValue("a", "runtime"):GetData())
    equal(2, analyzer:GetLocalOrEnvironmentValue("b", "runtime"):GetData())
    equal(3, analyzer:GetLocalOrEnvironmentValue("c", "runtime"):GetData())
end)


test("scopes shouldn't leak", function()
    local analyzer = R[[
        local a = {}
        function a:test(a, b)
            return nil, a+b
        end
        local _, a = a:test(1, 2)
    ]]

    equal(3, analyzer:GetLocalOrEnvironmentValue("a", "runtime"):GetData())
end)

test("explicitly annotated variables need to be set properly", function()
    local analyzer = R[[
        local a: number | string = 1
    ]]
end)

test("functions can modify parent scope", function()
    local analyzer = R[[
        local a = 1
        local c = a
        local function test()
            a = 2
        end
        test()
    ]]

    equal(2, analyzer:GetLocalOrEnvironmentValue("a", "runtime"):GetData())
    equal(1, analyzer:GetLocalOrEnvironmentValue("c", "runtime"):GetData())
end)

test("uncalled functions should be called", function()
    local analyzer = R[[
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
    local lib = analyzer:GetLocalOrEnvironmentValue("lib", "runtime")

    equal("number", lib:Get("foo1"):GetArguments():Get(1):GetType("number").Type)
    equal("number", lib:Get("foo1"):GetArguments():Get(2):GetType("number").Type)
    equal("number", lib:Get("foo1"):GetReturnTypes():Get(1).Type)

    equal("number", lib:Get("foo2"):GetArguments():Get(1):GetType("number").Type)
    equal("number", lib:Get("foo2"):GetArguments():Get(2):GetType("number").Type)
    equal("number", lib:Get("foo2"):GetReturnTypes():Get(1):GetType("number").Type)
end)

R[[
    local num = 0b01 -- binary numbers
    type_assert(num, 1)
]]

R([[
    local a: UNKNOWN_GLOBAL = true
]],
    "cannot find value UNKNOWN_GLOBAL"
)

R([[
    unknown_type_function<|1,2,3|>
]],
    "cannot find value unknown_type_function"
)

R([[
    local type should_error = function()
        error("the error")
    end

    should_error()
]], "the error")

R[[
    local function list()
        local tbl
        local i

        local self = {
            clear = function(self)
                tbl = {}
                i = 1
            end,
            add = function(self, val)
                tbl[i] = val
                i = i + 1
            end,
            get = function(self)
                return tbl
            end
        }

        self:clear()

        return self
    end


    local a = list()
    a:add(1)
    a:add(2)
    a:add(3)
    type_assert(a:get(), {1,2,3})
]]

R[[
    local FOO = enum<|{
        A = 1,
        B = 2,
        C = 3,
    }|>
    
    local x: FOO = 2
    type_assert(x, FOO)

    -- make a way to undefine enums
    type A = nil
    type B = nil
    type C = nil
]]

R[[
    local type Foo = {
        x = number,
        y = self,
    }

    local x = {} as Foo

    type_assert(x.y.y.y.x, _ as number)
]]

R[[
    local type Foo = {
        x = number,
        y = self,
    }

    local x = {} as Foo

    type_assert(x.y.y.y.x, _ as number)
]]


R[[
    local type Foo = {
        x = number,
        y = Foo,
    }

    local x = {} as Foo

    type_assert(x.y.y.y.x, _ as number)
]]

pending("forward declare types", function()
    R[[
        local type Ping = {}
        local type Pong = {}

        type Ping.pong = Pong
        type Pong.ping = Ping

        local x: Pong

        type_assert(x.ping.pong.ping, Ping)
        type_assert(x.ping.pong.ping.pong, Pong)
    ]]
end)

R([[type_error("hey over here")]], "type function type_error")

R([[
local a    
local b    
§error("LOL")
local c    

]], [[3 | §error%("LOL"%)]])

R([[
    local foo = function() return "hello" end

    local function test(cb: function(): number)

    end

    test(foo)
]], '"hello" is not the same type as')

R[[
    return function()

        local function foo(x)
            return x+3
        end
    
        local function bar(x)
            return foo(3)+x
        end
    
        local function faz(x)
            return bar(2)+x
        end
    
        type_expect(faz(1), 12)
    end
]]

R[[
    local type Boolean = true | false
    local type Number = -inf .. inf | nan
    local type String = $".*"
    local type Any = Number | Boolean | String | nil
    local type Table = {[exclude<|Any, nil|> | self] = Any | self}
    local type Function = (function(...Any): ...Any)

    do
        -- At this point, Any does not include the Function and Table type.
        -- We work around this by mutating the type after its declaration

        local type function extend_any(obj, func, tbl)
            obj:AddType(tbl)
            obj:AddType(func)
        end

        --extend_any<|Any, Function, Table|>
    end

    local a: Any
    local b: Boolean
    local a: String = "adawkd"

    local t: {
        [String] = Function,
    }

    local x,y,z = t.foo(a, b)
    
    type_assert(x, _ as Any)
    type_assert(y, _ as Any)
    type_assert(z, _ as Any)
]]

R[[
    -- we should be able to initialize with no value if the value can be nil
    local x: { y = number | nil } = {}
]]

R([[
    local x: { y = number } = {}
]], "y.-is missing from")

R[[
    local Foo = {Bar = {}}

    function Foo.Bar:init() end
]]

R[[
    function test(callback: (function(...): ...)) 

    end

    test(function(lol: boolean) 
    
    end)
]]