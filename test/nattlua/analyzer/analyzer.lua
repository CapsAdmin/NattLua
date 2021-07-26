local T = require("test.helpers")
local R = T.RunCode
local E = T.RunCode
local String = T.String

-- check that type assert works
E("types.assert(1, 2)", "expected.-2 got 1")
E("types.assert(nil as 1|2, 1)", "expected.-1")
E("types.assert<|string, number|>", "expected number got string")

R"types.assert(not true, false)"
R"types.assert(not 1, false)"
R"types.assert(nil == nil, true)"

test("declaring base types", function()
    R[[
        local type Symbol = function(T: any)
            return types.Symbol((loadstring or load)("return " .. T:GetNode().value.value)(), true)
        end
        
        -- primitive types
        local type Nil = Symbol(nil)
        local type True = Symbol(true)
        local type False = Symbol(false)
        local type Boolean = True | False
        local type Number = -inf .. inf | nan
        local type String = $".-"
        
        -- the any type is all types, but we need to add function and table later
        local type Any = Number | Boolean | String | Nil
        local type Function = function(...Any): ...Any
        local type Table = {[Any] = Any}
        
        local type function AddToUnion(union: any, what: any)
            -- this modifies the existing type rather than creating a new one
            union:AddType(what)
        end
        AddToUnion<|Any, Table|>
        AddToUnion<|Any, Function|>
        
        -- if the union sorting algorithm changes, we probably need to change this
        local type function check()
            local a = tostring(env.typesystem.Any)
            local b = "$(.-) | -inf..inf | false | function⦗⦗*self-union*⦘×inf⦘: ⦗⦗*self-union*⦘×inf⦘ | nan | nil | true | { *self-union* = *self-union* }"
            if a ~= b then
                print(a)
                print(b)
                error("signatures dont' match!")
            end
        end
        check<||>
        

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
        types.assert<|Foo == "asdf", false|>
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
         
        types.assert<|argument_type<|foo, 1|>, string|>
        types.assert<|argument_type<|foo, 2|>, number|>
        types.assert<|argument_type<|foo, 3|>, string|>
    ]=])

    R[=[
        --[[# local type a = 1 ]]
        types.assert(a, 1)
    ]=]
end)

test("runtime scopes", function()
    local v = R("local a = 1"):GetLocalOrEnvironmentValue(String("a"), "runtime")
    equal(true, v.Type == "number")
end)

test("default declaration is literal", function()
    R([[
        local a = 1
        local t = {k = 1}
        local b = t.k

        types.assert_literal<|a|>
        types.assert_literal<|b|>
    ]])
end)

test("runtime block scopes", function()

    local analyzer, syntax_tree = R("do local a = 1 end")
    equal(false, (syntax_tree.environments.runtime:Get(String("a"))))
    equal(1, analyzer:GetScope():GetChildren()[1].upvalues.runtime.map.a:GetValue():GetData()) -- TODO: awkward access

    local v = R[[
        local a = 1
        do
            local a = 2
        end
    ]]:GetLocalOrEnvironmentValue(String("a"), "runtime")

    equal(v:GetData(), 1)
end)

test("typesystem differs from runtime", function()
    local analyzer = R[[
        local a = 1
        local type a = 2
    ]]

    equal(analyzer:GetLocalOrEnvironmentValue(String("a"), "runtime"):GetData(), 1)
    equal(analyzer:GetLocalOrEnvironmentValue(String("a"), "typesystem"):GetData(), 2)
end)

test("global types", function()
    local analyzer = R[[
        do
            type a = 2
        end
        local b: a
        type a = nil
    ]]

    equal(2, analyzer:GetLocalOrEnvironmentValue(String("b"), "runtime"):GetData())
end)

test("constant types", function()
    local analyzer = R[[
        local a: 1
        local b: number
    ]]

    equal(true, analyzer:GetLocalOrEnvironmentValue(String("a"), "runtime"):IsLiteral())
    equal(false, analyzer:GetLocalOrEnvironmentValue(String("b"), "runtime"):IsLiteral())
end)

-- literal + vague = vague
test("1 + number = number", function()
    local analyzer = R[[
        local a: 1
        local b: number
        local c = a + b
    ]]

    local v = analyzer:GetLocalOrEnvironmentValue(String("c"), "runtime")
    equal(true, v.Type == ("number"))
    equal(false, v:IsLiteral())
end)

test("1 + 2 = 3", function()
    local analyzer = R[[
        local a = 1
        local b = 2
        local c = a + b
    ]]

    local v = analyzer:GetLocalOrEnvironmentValue(String("c"), "runtime")
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

    local v = analyzer:GetLocalOrEnvironmentValue(String("a"), "runtime")
    equal(6, v:GetData())
end)

test("multiple function return values", function()
    local analyzer = R[[
        local function test()
            return 1,2,3
        end
        local a,b,c = test()
    ]]

    equal(1, analyzer:GetLocalOrEnvironmentValue(String("a"), "runtime"):GetData())
    equal(2, analyzer:GetLocalOrEnvironmentValue(String("b"), "runtime"):GetData())
    equal(3, analyzer:GetLocalOrEnvironmentValue(String("c"), "runtime"):GetData())
end)


test("scopes shouldn't leak", function()
    local analyzer = R[[
        local a = {}
        function a:test(a, b)
            return nil, a+b
        end
        local _, a = a:test(1, 2)
    ]]

    equal(3, analyzer:GetLocalOrEnvironmentValue(String("a"), "runtime"):GetData())
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

    equal(2, analyzer:GetLocalOrEnvironmentValue(String("a"), "runtime"):GetData())
    equal(1, analyzer:GetLocalOrEnvironmentValue(String("c"), "runtime"):GetData())
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
    local lib = analyzer:GetLocalOrEnvironmentValue(String("lib"), "runtime")

    equal("number", assert(lib:Get(String("foo1")):GetArguments():Get(1):GetType("number")).Type)
    equal("number", assert(lib:Get(String("foo1")):GetArguments():Get(2):GetType("number")).Type)
    equal("number", assert(lib:Get(String("foo1")):GetReturnTypes():Get(1)).Type)

    equal("number", lib:Get(String("foo2")):GetArguments():Get(1):GetType("number").Type)
    equal("number", lib:Get(String("foo2")):GetArguments():Get(2):GetType("number").Type)
    equal("number", lib:Get(String("foo2")):GetReturnTypes():Get(1):GetType("number").Type)
end)

R[[
    local num = 0b01 -- binary numbers
    types.assert(num, 1)
]]

R([[
    local a: UNKNOWN_GLOBAL = true
]],
    "has no field.-UNKNOWN_GLOBAL"
)

R([[
    unknown_type_function<|1,2,3|>
]],
    "has no field.-unknown_type_function"
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
    types.assert(a:get(), {1,2,3})
]]

R[[
    local FOO = enum<|{
        A = 1,
        B = 2,
        C = 3,
    }|>
    
    local x: FOO = 2
    
    types.assert(x, _ as 1 | 2 | 3)

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

    types.assert(x.y.y.y.x, _ as number)
]]

R[[
    local type Foo = {
        x = number,
        y = self,
    }

    local x = {} as Foo

    types.assert(x.y.y.y.x, _ as number)
]]


R[[
    local type Foo = {
        x = number,
        y = Foo,
    }

    local x = {} as Foo

    types.assert(x.y.y.y.x, _ as number)
]]

test("forward declare types", function()
    R[[
        local type Ping = {}
        local type Pong = {}

        type Ping.pong = Pong
        type Pong.ping = Ping

        local x: Pong

        types.assert(x.ping.pong.ping, Ping)
        types.assert(x.ping.pong.ping.pong, Pong)
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
]], 'hello.-is not a subset of.-number')

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
    
    types.assert(x, _ as Any)
    types.assert(y, _ as Any)
    types.assert(z, _ as Any)
]]

R[[
    -- we should be able to initialize with no value if the value can be nil
    local x: { y = number | nil } = {}
]]

R([[
    local x: { y = number } = {}
]], "is not a subset of")

R[[
    local Foo = {Bar = {}}

    function Foo.Bar:init() end
]]

R[[
    function test2(callback: (function(...): ...)) 

    end

    test2(function(lol: boolean) 
    
    end)
]]

R[[
    local math = {}
    -- since math is defined explicitly as a local here
    -- it should not get its type from the base environment
    math = {}
]]

R[[
    local type function nothing()
        return -- return nothing, not even nil
    end

    -- when using in a comparison, the empty tuple should become a nil value instead
    local a = nothing() == nil
    
    types.assert(a, true)
]]

R[[
    a = {b = {c = {d = {lol = true}}}}
    function a.b.c.d:e()
        types.assert(self.lol, true)
    end
    a.b.c.d:e()
    a = nil
]]

R[[
    local a = {b = {c = {d = {lol = true}}}}
    function a.b.c.d:e()
        return self.lol
    end
    types.assert(a.b.c.d:e(), true)
]]

R[[
    type lib = {}
    type lib.myfunc = function(number, string): boolean

    local lib = {} as lib

    function lib.myfunc(a, b)
        return true
    end

    types.assert(lib.myfunc, _ as function(number, string): boolean)
]]

R[[
    local val: nan
    types.assert(val, 0/0)
]]

R[[
    local val: nil
    types.assert(val, nil)
]]

R[[
    local {Foo} = {}
    types.assert(Foo, nil)
]]

R([[
    local type {Foo} = {}
]], "Foo does not exist")

R[[
    local function test(num: number)
        types.assert<|num, number|>
        return num
    end
    
    local a = test(1)
    types.assert<|a, number|>
    
    
    local function test(num)
        types.assert<|num, 1|>
        return num
    end
    
    local a = test(1)
    types.assert<|a, 1|>
]]

R[[
    local type Shape = {
        Foo = number,
    }
    
    local function mutate(a: mutable Shape)
        a.Foo = 5
    end
    
    local tbl = {Foo = 1}
    mutate(tbl)
    types.assert<|tbl.Foo, 5|>
    
    local function mutate(a)
        a.Foo = 5
    end
    
    local tbl: Shape = {Foo = 1}
    mutate(tbl)
    types.assert_superset<|tbl.Foo, number|>
]]

R[[
    local T: Tuple<|boolean|> | Tuple<|1|2|>
    types.assert<|T, Tuple<|boolean|> | Tuple<|1|2|>|>
]]

R[[
    local x = {foo = 1, bar = 2}
    x.__index = x
    x.func = _ as (function(lol: x | nil): x)
    x.bar = _ as (function(lol: x): {lol = x})

    §assert(env.runtime.x:Equal(env.runtime.x:Copy()))
]]

R[[
    -- this has to do with the analyzer 
    -- not clearing self.lua_error_thrown when analyzing unreachable code

    local function build(name: string)
        return function()
            while math.random() > 0.5 do end
            types.assert(name, _ as string)
        end
    end
    
    local function lol(tbl: {[number] = string})
        return assert(loadstring("kernel"))
    end
    
    local foo = build("double")
    
    local function Read()    
        foo()
    end
]]