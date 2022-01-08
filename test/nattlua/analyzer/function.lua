local T = require("test.helpers")
local run = T.RunCode
local String = T.String

test("arguments", function()
    local analyzer = run[[
        local function test(a,b,c)
            return a+b+c
        end
        local a = test(1,2,3)
    ]]

    equal(6, analyzer:GetLocalOrGlobalValue(String("a")):GetData())
end)

test("arguments should get annotated", function()
    local analyzer = run[[
        local function test(a,b,c)
            return a+c
        end

        test(1,"",3)
    ]]

    local args = analyzer:GetLocalOrGlobalValue(String("test")):GetArguments()

    equal("number", args:Get(1):GetType("number").Type)
    equal("string", args:Get(2):GetType("string").Type)
    equal("number", args:Get(3):GetType("number").Type)

    local rets = analyzer:GetLocalOrGlobalValue(String("test")):GetReturnTypes()
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

    local func = analyzer:GetLocalOrGlobalValue(String("test"))

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

    local val = analyzer:GetLocalOrGlobalValue(String("a"))
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
    local c = analyzer:GetLocalOrGlobalValue(String("c"))
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

    local self = analyzer:GetLocalOrGlobalValue(String("a")):GetArguments():Get(1):GetType("table")
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

        local args = analyzer:GetLocalOrGlobalValue(String("test")):GetArguments()
        local a = args:Get(1)
        local b = args:Get(2)

        equal("number", a:GetType("number").Type)
        equal(1, a:GetType("number"):GetData())

        equal("string", b:GetType("string").Type)
        equal("a", b:GetType("string"):GetData())
    end

    do
        local analyzer = run[[
            local function test(a, b)
                return 1337
            end

            test(1,"a")
            test("a",1)
        ]]

        local args = analyzer:GetLocalOrGlobalValue(String("test")):GetArguments()
        local a = args:Get(1)
        local b = args:Get(2)

        assert(a:Equal(b))
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

        local args = analyzer:GetLocalOrGlobalValue(String("test")):GetArguments()
        local a = args:Get(1)
        local b = args:Get(2)

        assert(a:Equal(b))
    end


    local analyzer = run[[
        local function test(a, b)
            return 1337
        end

        test(1,2)
        test("awddwa",{})
    ]]
    local b = analyzer:GetLocalOrGlobalValue(String("b"))
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
    local a = analyzer:GetLocalOrGlobalValue(String("a"))
    local b = analyzer:GetLocalOrGlobalValue(String("b"))
    local c = analyzer:GetLocalOrGlobalValue(String("c"))

    equal(1, a:GetData())
    equal(2, b:GetData())
    equal(3, c:GetData())
end)

test("return type", function()
    local analyzer = run[[
        function foo(a: number):string return '' end
    ]]
end)

test("calling a union", function()
    run[[
        local type test = function=(boolean, boolean)>(number) | function=(boolean)>(string)

        local a = test(true, true)
        local b = test(true)

        attest.equal(a, _ as number)
        attest.equal(b, _ as string)
    ]]
end)

test("calling a union that has no field a function should error", function()
    run([[
        local type test = function=(boolean, boolean)>(number) | function=(boolean)>(string) | number

        test(true, true)
    ]], "union .- contains uncallable object number")
end)

test("pcall", function()
    pending[[
        local ok, err = pcall(function()
            local a, b = 10.5, nil
            return a < b
        end)

        attest.equal(ok, _ as false)
        attest.equal(err, _ as "not a valid binary operation")
    ]]
end)
test("complex", function()
    run[[
        local function foo()
            return foo()
        end
        
        foo()

        attest.superset_of(foo, nil as function=()>(any))
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
        local c: function=(a: number, b:number)>(b, b)

        attest.superset_of(
            c, 
            nil as function=(_:number, _:number)>({foo = any}, {foo = any})
        )

        type x = nil
    ]]
end)

test("lol2", function()
    run[[
        local function test(a:number,b: number)
            return a + b
        end

        test(1,1)

        attest.superset_of(test, nil as function=(_:number, _:number)>(number))
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
    ]]):GetLocalOrGlobalValue(String("foo"))
    
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
        
        attest.equal(val, 1)

        return val
    end

    attest.equal(a(), _ as 1 | "")
]]

run[[
    local x = (" "):rep(#tostring(_ as string))
    attest.equal(x, _ as string)
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
    attest.equal(f(), "foo")
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
    
    attest.equal(foo(1), _ as any)
]]

run[[
    local Foo = {Bar = {foo = {bar={test={}}}}}

    function Foo.Bar.foo.bar.test:init() end

    attest.superset_of(Foo.Bar.foo.bar.test.init, _ as function=(...any)>(...any))
]]

run[[
    local aaa = function(...) end
    function foo(...: number)
        aaa(...)
    end
]]


run[[
    local analyzer function test2(a: any, ...: ...any)
        local b,c,d = ...
        assert(a:GetData() == "1")
        assert(b:GetData() == 2)
        assert(c:GetData() == 3)
        assert(d:GetData() == 4)
    end
    
    local function test(a, ...)
        test2(a, ...)
    end
    
    test("1",2,3,4)
]]

run[[
    local function foo(a,b,c,d)
        attest.equal(a, 1)
        attest.equal(b, 2)
        attest.equal(c, _ as any)
        attest.equal(d, _ as any)
    end
    
    something(function(...)
        foo(1,2,...)
    end)
]]

run[[
    local func = function(one, two) end
    func(1, 2)
    func(1, "2")
]]

run[[
    local type Token = {
        type = string,
        value = string,
    }
    
    local tbl = {
        foo = 1,
        bar = 2,
        faz = 3,
    }
    
    local function foo(arg: Token)
        return tbl[arg.value]
    end
    
    attest.equal(foo({value = "test", type = "lol"}), _ as 1|2|3|nil)
    attest.equal(foo({value = "test", type = "lol"}), _ as 1|2|3|nil)
]]

run[[
    local function test()
        if MAYBE then
            return true
        end
    end
    
    local x = test()
    attest.equal(x, _ as nil | true)
]]

run[[
    local function test(cb: function=(string)>(string))

    end
    
    test(function(s)
        return ""
    end)

    §assert(#analyzer.diagnostics == 0)
]]

run[[
    local function test(): ref number 
        return 1
    end 
    
    local x = test()
    attest.equal(x, 1)
]]
run[[
    local function test(): number 
        return 1
    end 
    
    local x = test()
    attest.equal(x, _ as number)
]]

run[[
    local A = {kind = "a"}
    function A:Foo()
        return self.kind
    end
    
    local B = {kind = "b"}
    function B:Bar()
        return self.kind
    end
    
    local C = {kind = "c"}
    C.Foo = A.Foo
    C.Bar = B.Bar
    
    attest.equal(C:Foo(), "c")
    attest.equal(C:Bar(), "c")
    
    attest.equal(A:Foo(), "a")
    attest.equal(B:Bar(), "b")
]]

run[[
    local function foo(str: boolean | nil)

    end
    
    foo()
]]

run[[
    local function foo(x: { foo = nil | number })

    end

    foo({})
]]

run[[
    local type MyTable = {foo = number}

    local function foo(tbl: MyTable & {bar = boolean | nil})
        attest.equal<|tbl.foo, number|>
        attest.equal<|tbl.bar, boolean | nil|>
        return tbl
    end

    local tbl = foo({
        foo = 1337
    })

    attest.equal<|tbl.foo, number|>
    attest.equal<|tbl.bar, boolean | nil|>
]]

run[[
    local meta = {}
    meta.__index = meta
    type meta.@Self = {foo = number}
    
    local function test(tbl: meta.@Self & {bar = string | nil})
        attest.equal(tbl.bar, _ as nil | string)
        return tbl:Foo() + 1
    end
    
    function meta:Foo()
        attest.equal<|self.foo, number|>
        return 1336
    end
    
    local obj = setmetatable({
        foo = 1
    }, meta)
    
    attest.equal(obj:Foo(), 1336)
    attest.equal(test(obj), 1337)
]]

pending[[
    -- strange error
    type foo = (function(
        boolean | nil, 
        boolean | nil, 
        string, 
        number | nil
    ): nil)
    
    foo(true)
]]

run[[
    local tbl = {}

    local function add(
        name: ref string
    )
        tbl[name] = function(name2: ref string)
            attest.equal(name, name2)
        end
    end
    
    add("FooNumber")
    add("BarString")
    
    tbl.FooNumber("FooNumber")
    tbl.BarString("BarString")
]]

run[[
    local type mytuple = (string, number, boolean)
    local type lol = function=(mytuple)>(mytuple)

    attest.equal(lol, _ as function=(string, number, boolean)>(string, number, boolean))
]]

run[[
    type lol = function =(foo: string, number)>(bar: string, string)

    attest.equal(lol, _ as function =(string, number)>(string, string))
]]

run[[
    local function test!(T: any)
        if T == string then
            return expand setmetatable({}, {__call = function(_, a: ref T, b: ref T)
            §assert(analyzer:GetCurrentAnalyzerEnvironment() == "runtime", "analyzer environment is not runtime")
            return a .. b end})
        else
            return expand setmetatable({}, {__call = function(_, a: ref T, b: ref T) return a + b end})
        end
    end
    
    local a = test!(number)(1,2)
    local b = test!(string)("1","2")
    
    attest.equal(a, 3)
    attest.equal(b, "12")    
]]

run[[
    local type Type = "foo" | "bar" 
    local type Object = {
        foo = Type,
        --[1337] = 1, TODO, this should error
    }

    local table_pool = function(alloc: ref (function=()>({[string] = any})))
        local pool = {} as {[number] = return_type<|alloc|>[1]}
        return function()
            return pool[1]
        end
    end

    local tk = table_pool(function() return { foo = "foo" } as Object end)()
    tk.foo = "bar"
    attest.equal<|tk.foo, Type|>
]]

run([[
    local type Type = "foo" | "bar" 
    local type Object = {
        [1337] = 1,
    }

    local table_pool = function(alloc: ref (function=()>({[string] = any})))
        local pool = {} as {[number] = return_type<|alloc|>[1]}
        return function()
            return pool[1]
        end
    end

    table_pool(function() return { [777] = 777 } as Object end)()
]], "777 is not the same type as string")


run[[
    local function foo(x: function=(number, string)>())

    end
    
    foo(function(x, y)
        attest.equal(x, _ as number)
        attest.equal(y, _ as string)
    end)
]]

run[[
    local function foo(x: function=(number, string)>())

    end
    
    foo(function(x: number)
        attest.equal(x, _ as number)
    end)
]]

run[[
    local foo = function(s: string)
        return "code" as string
    end
    
    (function(arg: {[number] = string})
        local code = foo(arg[1])
        attest.equal(code, _ as string)
    end)(arg)
]]

run[[
    local function IREqual(IR1: {number, number})
        return true
    end
    
    local function replaceIRs(haystack: {[number] = {number, number}})
        § assert(#env.runtime.haystack.contracts == 1)
        local i: number
        IREqual(haystack[i])
        § assert(#env.runtime.haystack.contracts == 1)
        IREqual(haystack[i])
        § assert(#env.runtime.haystack.contracts == 1)
    end
    
    local instList = {{1, 0}}
    § assert(#env.runtime.instList.contracts == 0)
    replaceIRs(instList)
    § assert(#env.runtime.instList.contracts == 0)    
]]

run[[
    local z = 2
    do
        local function WORD(low: number, high: number)
        end
    
        do
            local function WSAStartup(a: any,b: any) end
            local x = 1
    
            local wsa_data = _ as function=()>() | nil
    
            local function initialize()
                -- make sure  parent scope of initialize is preserved when scope is cloned
                § analyzer.SuppressDiagnostics = true
                local data = wsa_data() -- scope clone occurs here because wsdata can be nil
                § analyzer.SuppressDiagnostics = nil
    
                attest.equal(x, 1)
                attest.equal(z, 2)
    
                WSAStartup(WORD(2, 2), data)
            end
        end
    end
]]

run[[
    local func: function=(number, string)>(nil)
    local x: function=(Parameters<|func|>)>(nil)
    attest.equal(x, func)
]]

run[[
    local analyzer function foo(n: number): number, string
        return types.LNumber(1337), types.LString("foo")
    end
    
    local x,y = foo(1)
    attest.equal(x, 1337)
    attest.equal(y, "foo")
    
    attest.equal<|foo, function=(number)>(number, string)|>
]]

run([[
    local function foo(s: ref literal string)
        return s
    end
    
    foo(_ as string)    
]], "not literal")

run[[
    local function foo(str: literal ref (nil | string))
        return str
    end
    attest.equal(foo("hello"), "hello")
]]