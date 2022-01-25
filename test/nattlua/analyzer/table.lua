local T = require("test.helpers")
local run = T.RunCode
local String = T.String

test("reassignment", function()
    local analyzer = run[[
        local tbl = {}
        tbl.foo = true
        tbl.foo = false
    ]]

    local tbl = analyzer:GetLocalOrGlobalValue(String("tbl"))

    equal(false, tbl:Get(String("foo")):GetData())

    local analyzer = run[[
        local tbl = {foo = true}
        tbl.foo = false
    ]]

    local tbl = analyzer:GetLocalOrGlobalValue(String("tbl"))
    equal(false, tbl:Get(String("foo")):GetData())
end)

test("typed field", function()
    local analyzer = run[[
        local tbl: {foo = boolean} = {foo = true}
    ]]
    equal(true, analyzer:GetLocalOrGlobalValue(String("tbl")):Get(String("foo")):GetData())
end)

test("typed table invalid reassignment should error", function()
    local analyzer = run(
        [[
            local tbl: {foo = 1} = {foo = 2}
        ]]
        ,"2 is not a subset of 1"
    )
end)

test("typed table invalid reassignment should error", function()
    local analyzer = run(
        [[
            local tbl: {foo = 1} = {foo = 1}
            tbl.foo = 2
        ]]
        ,"2 is not a subset of 1"
    )
    local v = analyzer:GetLocalOrGlobalValue(String("tbl"))

    run(
        [[
            local tbl: {foo = {number, number}} = {foo = {1,1}}
            tbl.foo = {66,66}
            tbl.foo = {1,true}
        ]]
        ,".-true is not a subset of.-number"
    )
end)

test("typed table correct assignment not should error", function()
    run([[
        local tbl: {foo = true} = {foo = true}
        tbl.foo = true
    ]])
end)

test("self referenced tables should be equal", function()
    local analyzer = run([[
        local a = {a=true}
        a.foo = {lol = a}

        local b = {a=true}
        b.foo = {lol = b}
    ]])

    local a = analyzer:GetLocalOrGlobalValue(String("a"))
    local b = analyzer:GetLocalOrGlobalValue(String("b"))

    local ok, err = a:IsSubsetOf(b)
    if not ok then
        error(err)
    end
    equal(true, ok)
end)

test("indexing nil in a table should be allowed", function()
    local analyzer = run([[
        local tbl = {foo = true}
        local a = tbl.bar
    ]])

    equal("symbol", analyzer:GetLocalOrGlobalValue(String("a")).Type)
    equal(nil, analyzer:GetLocalOrGlobalValue(String("a")):GetData())
end)

test("indexing nil in a table with a contract should error", function()
    run([[
        local tbl: {foo = true} = {foo = true}
        local a = tbl.bar
    ]], "\"bar\" is not the same value as \"foo\"")
end)

test("string: any", function()
    run([[
        local a: {[string] = any | nil} = {} -- can assign a string to anything, (most common usage)
        a.lol = "aaa"
        a.lol2 = 2
        a.lol3 = {}
    ]])
end)

test("empty type table shouldn't be writable", function()
    run([[
        local a: {} = {}
        a.lol = true
    ]], "has no field .-lol")
end)

test("wrong right hand type should error", function()
    run([[
        local {a,b} = nil
    ]], "expected a table on the right hand side, got")
end)

test("should error when key doesn't match the type", function()
    run([[
        local a: {[string] = string | nil} = {}
        a.lol = "a"
        a[1] = "a"
    ]], "is not the same type as string")
end)

test("with typed numerically indexed table should error", function()
    run([[
        local tbl: {1,true,3} = {1, true, 3}
        tbl[2] = false
    ]], "false is not the same value as true")
end)

test("which has no data but contract says it does should return what the contract says", function()
    run[[
        local tbl = {} as {[string] = 1}
        attest.equal(tbl.foo, 1)
    ]]

    run([[
        local tbl = {} as {[string] = 1}
        attest.equal(tbl[true], nil)
    ]], "has no field true")
end)

test("is literal", function()
    local a = run[[
        local type a = {a = 1, b = 2}
    ]]

    a:PushAnalyzerEnvironment("typesystem")
    equal(a:GetLocalOrGlobalValue(String("a")):IsLiteral(), true)
    a:PopAnalyzerEnvironment()
    
    local a = run[[
        local type a = {a = 1, b = 2, c = {c = true}}
        ]]
        
    a:PushAnalyzerEnvironment("typesystem")
        equal(a:GetLocalOrGlobalValue(String("a")):IsLiteral(), true)
    a:PopAnalyzerEnvironment()
end)

test("is not literal", function()
    local a = run[[
        local type a = {a = number, [string] = boolean}
    ]]
    a:PushAnalyzerEnvironment("typesystem")
    equal(a:GetLocalOrGlobalValue(String("a")):IsLiteral(), false)
    a:PopAnalyzerEnvironment()

    local a = run[[
        local type a = {a = 1, b = 2, c = {c = boolean}}
    ]]
    a:PushAnalyzerEnvironment("typesystem")
    equal(a:GetLocalOrGlobalValue(String("a")):IsLiteral(), false)
    a:PopAnalyzerEnvironment()
end)

test("self reference", function()
    local a = run[[
        local type Base = {
            Test = function=(self, number)>(number),
        }

        local type Foo = Base extends {
            GetPos = function=(self)>(number),
        }

        -- have to use as here because {} would not be a subset of Foo
        local x = _ as Foo
        
        attest.equal(x:Test(1), _ as number)
        attest.equal(x:GetPos(), _ as number)

        local func = x.Test
    ]]

    equal(a:GetLocalOrGlobalValue(String("func")):GetArguments():Get(1):Get(String("GetPos")).Type, "function")
    equal(a:GetLocalOrGlobalValue(String("func")):GetArguments():Get(1):Get(String("Test")).Type, "function")
    

    run[[
        local type a = {
            foo = self,
        }

        local type b = {
            bar = true,
        } extends a

        attest.equal<|b.bar, true|>
        attest.equal<|b.foo, b|>
    ]]
end)

test("table extending table", function()
    run[[
        local type A = {
            Foo = true,
        }

        local type B = {
            Bar = false,
        }

        attest.equal<|A extends B, {Foo = true, Bar = false}|>
    ]]
end)

test("table + table", function()
    run[[
        local type A = {
            Foo = true,
            Bar = 1,
        }

        local type B = {
            Bar = false,
        }

        attest.equal<|A + B, {Foo = true, Bar = false}|>
    ]]
end)

test("index literal table with string", function()
    run[[
        local tbl = {
            [ '"' ] = 1,
            [ "0" ] = 2,
        }

        local key: string
        local val = tbl[key]
        attest.equal(val, _ as 1 | 2 | nil)
    ]]
end)

test("non literal keys should be treated as literals when used multiple times in the same scope", function() 
    pending[[
        local foo: string
        local bar: string

        local a = {}
        a[foo] = a[foo] or {}
        a[foo][bar] = a[foo][bar] or 1

        attest.equal(a[foo][bar], 1)
    ]]
end)

test("table is not literal", function()
    run[[
        local tbl:{[number] = number} = {1,2,3}
        local analyzer function check_literal(tbl: any)
            assert(tbl:IsLiteral() == false)
        end
        check_literal(tbl)
    ]]
end)

test("var args with unknown length", function()
    run[[
        local tbl = {...}
        attest.equal(tbl[1], _ as any)
        attest.equal(tbl[2], _ as any)
        attest.equal(tbl[100], _ as any)
    ]]
end)

run[[
    local list: {[number] = any} | {}
    list = {}
    attest.equal(list, _ as {})
    attest.equal<|list, {[number] = any} | {}|>
]]

run[[
    local a = {foo = true, bar = false, 1,2,3}
    attest.equal(a[1], 1)
    attest.equal(a[2], 2)
    attest.equal(a[3], 3)
]]

test("deep nested copy", function() 
    local a = run([[
        local a = {nested = {}}
        a.a = a
        a.nested.a = a
    ]]):GetLocalOrGlobalValue(String("a"))

    equal(a:Get(String("nested")):Get(String("a")), a)
    equal(a:Get(String("a")), a)
    equal(a:Get(String("a")), a:Get(String("nested")):Get(String("a")))
end)

run[[
    local lol = {
        foo = true,
        bar = false,
        lol = 1,
    }
    
    local function test(token)
        -- here token is, string | string, but it should be string when being used as key
        return lol[token]
    end         
    
    local x = test(lol as string | string)
    attest.equal(x, _ as 1 | true | false | nil)    
]]

run[[
    local type T = {Foo = "something" | nil, Bar = "definetly"}

    local a = {} as T
    attest.equal<|a.Foo, nil | "something"|>

    a.Foo = nil
    attest.equal(a.Foo, nil)

    a.Foo = "something"
    attest.equal(a.Foo, "something")


    a.Foo = _ as "something" | nil
    attest.equal<|a.Foo, "something" | nil|>

    attest.equal<|a.Bar, "definetly"|>
]]

run[[
    local function fill(t)
        t.foo = true
    end
    
    local tbl = {}
    fill(tbl)
    attest.equal(tbl.foo, true)
]]

run[[
    local function fill(t: mutable {foo = boolean, bar = number})
        t.foo = true
    end
    
    local tbl = {bar = 1, foo = false}
    fill(tbl)
    attest.equal(tbl.foo, true)
]]

run[[
    local type ShapeA = {Foo = boolean | nil}
    local type ShapeB = {Bar = string | nil}
    
    local function mutate(obj: mutable ShapeA & ShapeB)
        obj.Bar = "asdf"
    end
    
    local obj = {}
    mutate(obj)
]]

run([[
    local type ShapeA = {Foo = boolean | nil}
    local type ShapeB = {Bar = string | nil}

    local function mutate(obj: ShapeA & ShapeB)
        obj.Bar = "asdf"
    end

    local obj = {Foo = "hm"}
    mutate(obj)
]], "mutating function argument")

run[[
    local type ShapeA = {Foo = boolean | nil}
    local type ShapeB = {Bar = string | nil}

    local function mutate(obj: ShapeA & ShapeB)

    end

    local obj = {}
    -- should be okay, because all the values in the contract can be nil
    mutate(obj)
]]

run([[
    local type ShapeA = {Foo = boolean}
    local type ShapeB = {Bar = string}

    local function mutate(obj: ShapeA & ShapeB)

    end

    local obj = {}
    mutate(obj)
]], "{ } has no field.-Foo")

run([[
    local type ShapeA = {Foo = boolean}
    local type ShapeB = {Bar = string}

    local function mutate(obj: ShapeA & ShapeB)

    end

    local obj = {Foo = true}
    mutate(obj)
]], "has no field \"Bar\"")


run[[
    local type Foo = {}
    local type Bar = {
        field = number | nil,
    }

    local function test(ent: Foo & Bar)
        attest.equal(ent.field, _ as nil | number)
        ent.field = 1
        attest.equal(ent.field, _ as 1)
        ent.field = nil
        attest.equal(ent.field, _ as nil)
    end

    test(_ as Foo & Bar)
]]


run[[
    local type Foo = {}
    local type Bar = {
        field = number | nil,
    }

    local function test(ent: Foo & Bar)
        attest.equal(ent.field, _ as nil | number)
        ent.field = 1
        attest.equal(ent.field, _ as 1)
        ent.field = nil
        attest.equal(ent.field, _ as nil)
    end
]]

run[[
    local type Entity = {
        GetModel = function=(self)>(string),
        GetBodygroup = function=(self, number)>(number),
    }

    type Entity.@Name = "Entity"

    local type HeadPos = {
        findheadpos_head_bone = number | nil,
        findheadpos_head_attachment = string | nil,
        findheadpos_last_mdl = string | nil,
    }

    local function FindHeadPosition(ent: Entity & HeadPos)
        
        if ent.findheadpos_last_mdl ~= ent:GetModel() then
            ent.findheadpos_head_bone = nil
            ent.findheadpos_head_attachment = nil
            ent.findheadpos_last_mdl = ent:GetModel()
        end
        
    end
]]

run[[
    attest.equal({Unknown()}, _ as {[1 .. inf] = any})
    attest.equal({Unknown(), 1}, _ as {any, 1})
]]


run[[

    local function test(tbl: ref {
        Foo = boolean,
        Bar = number,
        [string] = any,
    })
        attest.equal(tbl.Foo, _ as true)
        attest.equal(tbl.Bar, _ as 1337)
    
        tbl.NewField = 8888
        tbl.NewField2 = 9999
    
        attest.equal(tbl.NewField, 8888)
        attest.equal(tbl.NewField2, 9999)
    end
    
    local tbl = {Foo = true, Bar = 1337}
    
    test(tbl)
    
    attest.equal(tbl.Foo, _ as true)
    attest.equal(tbl.Bar, _ as 1337)
    attest.equal(tbl.NewField, 8888)
    attest.equal(tbl.NewField2, 9999)
    
]]

run[[
    local e = {}

    e.FOO = 1337
    
    if math.random() > 0.5 then
        e.FOO = 666
    end
    
    for k,v in pairs(e) do
        attest.equal(k, "FOO")
        attest.equal(v, _ as 666 | 1337)
    end
]]

run[[
    local META = {}

    function META:Test()

    end

    if not META["Foo"] then
        
    end

    §assert(#analyzer.diagnostics == 1)
]]


run([[
    local META = {} as {Test = function=(self)>(nil)}

    function META:Test()
    
    end
    
    if not META["Foo"] then
        
    end
]], "has no field \"Foo\"")

pending[[
    local function tbl_get_foo(self)
        attest.equal(self.foo, 1337)
        return tbl.foo
    end

    local tbl = {}
    tbl.foo = 1337
    tbl.get_foo = tbl_get_foo
]]

run[[
    local function foo(tbl: {
        [number] = true,
        foo = true,
        bar = false,
    }) 
        local x = tbl[_ as number]
        local y = tbl[1]
        local z = tbl[_ as string]
        attest.equal(x,y)
        attest.equal(z, _ as nil | boolean)
    end
]]

run[[
    local lol: number
    local t = {}

    t[lol] = 1
    t[lol] = 2
    attest.equal(t[lol], 2)
]]

run([[
    local RED = 1
    local BLUE = 2
    local GREEN: string
    local x: {[1 .. inf] = number} = {
        [RED] = 2,
        [BLUE] = 3,
        [GREEN] = 4,
    }
]], "has no field string")

run[[
    local type Foo = { bar = 1337 }
    local type Bar = { foo = 8888 }
    attest.equal<|Foo + Bar, Foo & Bar|>
]]

run[[
    local tbl = {}
    tbl.foo = true
    tbl.bar = false

    local key = _ as "foo" | "bar"
    attest.equal<|tbl[key], true | false|>
]]

run[[
    local tbl = _ as {foo = true} | {foo = false}
    attest.equal<|tbl.foo, true | false|>
]]

run[[
    local analyzer function test(a: any, b: any)
        analyzer:Assert(analyzer.current_expression, b:IsSubsetOf(a))
    end
    
    test(_ as {foo = number}, _ as {foo = number, bar = nil | number})
]]

run([[
    local t = {} as {
        foo = {foo = string}    
    }
    t.foo["test"] = true
]], "is not the same value as .-foo")

run[[
    local META =  {}
    META.__index = META

    type META.@Self = {
        foo = true,
    }

    local type x = META.@Self & {bar = false}
    attest.equal<|x, {foo = true, bar = false}|>
    attest.equal(META.@Self, _ as {foo = true})
]]

run[[
    local t = {} as {[1 .. inf] = number}
    attest.equal(#t, _ as 1 .. inf)
]]

run[[

    local function test<||>
        -- make sure we are analyzing nodes in the typesystem
        return {
            a = 1 | 2,
            b = function=(string)>(number),
        }
    end

    attest.equal(test().a, _ as 1 | 2)
    attest.equal(test().b, _ as function=(string)>(number))
]]

run[[
    local function create_set(...)
        local res = {}
        for i = 1, select("#", ...) do
            res[ select(i, ...) ] = true
        end
        return res
    end
    
    local space_chars   = create_set(" ", "\t", "\r", "\n")
    attest.equal(space_chars, {
        [" "] = true,
        ["\t"] = true,
        ["\r"] = true,
        ["\n"] = true,
    })
]]

run[[
    local throw = function() error("!") end

    local map = {
        foo = function() if math.random() > 0.5 then throw() end return 1 end,
        bar = function() if math.random() > 0.5 then throw() end return 2 end,
    }

    local function main()
        local x = map[_ as string]
        if x then
            local val = x()
            return val
        end
        error("nope")
    end

    attest.equal(main(), _ as 1 | 2)
]]

run[[
    local tbl = {}
    table.insert(tbl, _ as number)
    table.insert(tbl, _ as string)
    attest.equal(tbl, {_ as number, _ as string})
]]

run[[
    local type t = {[any] = any}
    attest.equal(t["foo" as string], _ as any)
]]

run[[
    local META = {}
    META.__index = META
    type META.@Self = {}

    function META.GetSet(name: ref string, default: ref any)
        META[name] = default
        type META.@Self[name] = META[name]
    end

    META.GetSet("Name", nil as nil | META.@Self)
    META.GetSet("Literal", false)

    function META:SetName(name: META.@Self)
        self.Name = name
    end
]]

run[[
    local type T = {
        foo = Table,
    }
    
    local x = {} as T
    
    x.foo.lol = true
    
    attest.equal(Table, _ as {[any] = any} | {})
]]

run[[
    
    local luadata = {}

    local type Context = {
        done = Table
    }
    function luadata.SetModifier(type: string, callback: function=(any, Context)>(nil), func: nil, func_name: nil)
    
    end
    
    luadata.SetModifier("table", function(tbl, context)
        context.done[tbl] = true
    
        attest.equal(Table, _ as {[any] = any} | {})
    end)
]]

run[[
    local lookup = {
        [_ as 1 | 2] = "foo",
        [_ as 1337 | 155] = "bar",
    }
    
    attest.equal(lookup[_ as number], _ as "foo" | "bar" | nil)
]]