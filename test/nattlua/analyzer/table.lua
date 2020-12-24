local T = require("test.helpers")
local run = T.RunCode

test("reassignment", function()
    local analyzer = run[[
        local tbl = {}
        tbl.foo = true
        tbl.foo = false
    ]]

    local tbl = analyzer:GetLocalOrEnvironmentValue("tbl", "runtime")

    equal(false, tbl:Get("foo"):GetData())

    local analyzer = run[[
        local tbl = {foo = true}
        tbl.foo = false
    ]]

    local tbl = analyzer:GetLocalOrEnvironmentValue("tbl", "runtime")
    equal(false, tbl:Get("foo"):GetData())
end)

test("typed field", function()
    local analyzer = run[[
        local tbl: {foo = boolean} = {foo = true}
    ]]
    equal(true, analyzer:GetLocalOrEnvironmentValue("tbl", "runtime"):Get("foo"):GetData())
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
    local v = analyzer:GetLocalOrEnvironmentValue("tbl", "runtime")

    run(
        [[
            local tbl: {foo = {number, number}} = {foo = {1,1}}
            tbl.foo = {66,66}
            tbl.foo = {1,true}
        ]]
        ,"true is not a subset of number"
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

    local a = analyzer:GetLocalOrEnvironmentValue("a", "runtime")
    local b = analyzer:GetLocalOrEnvironmentValue("b", "runtime")

    local ok, err = a:IsSubsetOf(b)
    if not ok then
        error(err)
    end
    equal(true, ok)
end)
do return end
test("indexing nil in a table should be allowed", function()
    local analyzer = run([[
        local tbl = {foo = true}
        local a = tbl.bar
    ]])

    equal("symbol", analyzer:GetLocalOrEnvironmentValue("a", "runtime").Type)
    equal(nil, analyzer:GetLocalOrEnvironmentValue("a", "runtime"):GetData())
end)

test("indexing nil in a table with a contract should error", function()
    run([[
        local tbl: {foo = true} = {foo = true}
        local a = tbl.bar
    ]], "\"bar\" is not a subset of \"foo\"")
end)

test("string: any", function()
    run([[
        local a: {[string] = any} = {} -- can assign a string to anything, (most common usage)
        a.lol = "aaa"
        a.lol2 = 2
        a.lol3 = {}
    ]])
end)

test("empty type table shouldn't be writable", function()
    run([[
        local a: {} = {}
        a.lol = true
    ]], "table has no definitions")
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
    ]], "false is not the same as true")
end)

test("which has no data but contract says it does should return what the contract says", function()
    run[[
        local tbl = {} as {[string] = 1}
        type_assert(tbl.foo, 1)
    ]]

    run([[
        local tbl = {} as {[string] = 1}
        type_assert(tbl[true], nil)
    ]], "true is not the same as string")
end)

test("is literal", function()
    local a = run[[
        local type a = {a = 1, b = 2}
    ]]
    equal(a:GetLocalOrEnvironmentValue("a", "typesystem"):IsLiteral(), true)

    local a = run[[
        local type a = {a = 1, b = 2, c = {c = true}}
    ]]
    equal(a:GetLocalOrEnvironmentValue("a", "typesystem"):IsLiteral(), true)
end)

test("is not literal", function()
    local a = run[[
        local type a = {a = number, [string] = boolean}
    ]]
    equal(a:GetLocalOrEnvironmentValue("a", "typesystem"):IsLiteral(), false)

    local a = run[[
        local type a = {a = 1, b = 2, c = {c = boolean}}
    ]]
    equal(a:GetLocalOrEnvironmentValue("a", "typesystem"):IsLiteral(), false)
end)

test("self reference", function()
    local a = run[[
        local type Base = {
            Test = function(self, number): number,
        }

        local type Foo = Base extends {
            GetPos = (function(self): number),
        }

        -- have to use as here because {} would not be a subset of Foo
        local x = _ as Foo
        
        type_assert(x:Test(1), _ as number)
        type_assert(x:GetPos(), _ as number)

        local func = x.Test
    ]]

    equal(a:GetLocalOrEnvironmentValue("func", "runtime"):GetArguments():Get(1):Get("GetPos").Type, "function")
    equal(a:GetLocalOrEnvironmentValue("func", "runtime"):GetArguments():Get(1):Get("Test").Type, "function")

    run[[
        local type a = {
            foo = self,
        }

        local type b = {
            bar = true,
        } extends a

        type_assert<|b.bar, true|>
        type_assert<|b.foo, b|>
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

        type_assert<|A extends B, {Foo = true, Bar = false}|>
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

        type_assert<|A + B, {Foo = true, Bar = false}|>
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
        type_assert(val, _ as 1 | 2 | nil)
    ]]
end)

test("non literal keys should be treated as literals when used multiple times in the same scope", function() 
    run[[
        local foo: string
        local bar: string

        local a = {}
        a[foo] = a[foo] or {}
        a[foo][bar] = a[foo][bar] or 1

        type_assert(a[foo][bar], 1)
    ]]
end)

test("table is not literal", function()
    run[[
        local tbl:{[number] = number} = {1,2,3}
        local type function check_literal(tbl)
            assert(tbl:IsLiteral() == false)
        end
        check_literal(tbl)
    ]]
end)

test("var args with unknown length", function()
    run[[
        local tbl = {...}
        type_assert(tbl[1], _ as any)
        type_assert(tbl[2], _ as any)
        type_assert(tbl[100], _ as any)
    ]]
end)

run[[
    local list: {[number] = any} | {}
    list = {}
    type_assert(list, _ as {[number] = any} | {})
]]

run[[
    local a = {foo = true, bar = false, 1,2,3}
    type_assert(a[1], 1)
    type_assert(a[2], 2)
    type_assert(a[3], 3)
]]

test("deep nested copy", function() 
    local a = run([[
        local a = {nested = {}}
        a.a = a
        a.nested.a = a
    ]]):GetLocalOrEnvironmentValue("a", "runtime")

    equal(a:Get("nested"):Get("a"), a)
    equal(a:Get("a"), a)
    equal(a:Get("a"), a:Get("nested"):Get("a"))
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
    type_assert(x, _ as 1 | true | false | nil)    
]]

run[[
    local type T = {Foo = "something" | nil, Bar = "definetly"}

    local a = {} as T
    type_assert<|a.Foo, nil | "something"|>

    a.Foo = nil
    type_assert<|a.Foo, nil|>

    a.Foo = "something"
    type_assert<|a.Foo, "something"|>


    a.Foo = _ as "something" | nil
    type_assert<|a.Foo, "something" | nil|>

    type_assert<|a.Bar, "definetly"|>
]]

run[[
    local function fill(t)
        t.foo = true
    end
    
    local tbl = {}
    fill(tbl)
    type_assert(tbl.foo, true)
]]

run[[
    local function fill(t: {foo = boolean, bar = number})
        t.foo = true
    end
    
    local tbl = {bar = 1, foo = false}
    fill(tbl)
    type_assert(tbl.foo, true)
]]

run[[
    local type ShapeA = {Foo = boolean | nil}
    local type ShapeB = {Bar = string | nil}
    
    local function mutate(obj: ShapeA & ShapeB)
        obj.Bar = "asdf"
    end
    
    local obj = {}
    mutate(obj)
    type_assert<|obj.Bar, "asdf"|>
]]

run([[
    local type ShapeA = {Foo = boolean | nil}
    local type ShapeB = {Bar = string | nil}

    local function mutate(obj: ShapeA & ShapeB)
        obj.Bar = "asdf"
    end

    local obj = {Foo = "hm"}
    mutate(obj)
    type_assert<|obj.Bar, "asdf"|>
]], "is not the same type as true")

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
    -- should be okay, because all the values in the contract can be nil
    mutate(obj)
]], "table is empty")

run([[
    local type ShapeA = {Foo = boolean}
    local type ShapeB = {Bar = string}

    local function mutate(obj: ShapeA & ShapeB)

    end

    local obj = {Foo = true}
    -- should be okay, because all the values in the contract can be nil
    mutate(obj)
]], "table is empty")


run[[
    local type Foo = {}
    local type Bar = {
        field = number | nil,
    }

    local function test(ent: Foo & Bar)
        type_assert(ent.field, _ as nil | number)
        ent.field = 1
        type_assert(ent.field, _ as 1)
        ent.field = nil
        type_assert(ent.field, _ as nil)
    end

    test(_ as Foo & Bar)
]]


run[[
    local type Foo = {}
    local type Bar = {
        field = number | nil,
    }

    local function test(ent: Foo & Bar)
        type_assert(ent.field, _ as nil | number)
        ent.field = 1
        type_assert(ent.field, _ as 1)
        ent.field = nil
        type_assert(ent.field, _ as nil)
    end
]]

run[[
    local type Entity = {
        GetModel = (function(self): string),
        GetBodygroup = (function(self, number): number),
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
    type_assert({Unknown()}, _ as {[1 .. inf] = any})
    type_assert({Unknown(), 1}, _ as {any, 1})
]]


run[[

    local function test(tbl: {
        Foo = boolean,
        Bar = number,
        [string] = any,
    })
        type_assert(tbl.Foo, _ as boolean)
        type_assert(tbl.Bar, _ as number)
        type_assert(tbl.lol, _ as any)
    
        tbl.NewField = 8888
        tbl.NewField2 = 9999
    
        type_assert(tbl.NewField, 8888)
        type_assert(tbl.NewField2, 9999)
    end
    
    local tbl = {Foo = true, Bar = 1337}
    
    test(tbl)
    
    type_assert(tbl.Foo, _ as boolean)
    type_assert(tbl.Bar, _ as number)
    type_assert(tbl.NewField, 8888)
    type_assert(tbl.NewField2, 9999)
    
]]

run[[
    local e = {}

    e.FOO = 1337
    
    if math.random() > 0.5 then
        e.FOO = 666
    end
    
    for k,v in pairs(e) do
        type_assert(k, "FOO")
        type_assert(v, _ as 666 | 1337)
    end
]]