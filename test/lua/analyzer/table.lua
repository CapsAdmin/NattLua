local T = require("test.helpers")
local run = T.RunCode

test("reassignment", function()
    local analyzer = run[[
        local tbl = {}
        tbl.foo = true
        tbl.foo = false
    ]]

    local tbl = analyzer:GetValue("tbl", "runtime")

    equal(false, tbl:Get("foo"):GetData())

    local analyzer = run[[
        local tbl = {foo = true}
        tbl.foo = false
    ]]

    local tbl = analyzer:GetValue("tbl", "runtime")
    equal(false, tbl:Get("foo"):GetData())
end)

test("typed field", function()
    local analyzer = run[[
        local tbl: {foo = boolean} = {foo = true}
    ]]
    equal(true, analyzer:GetValue("tbl", "runtime"):Get("foo"):GetData())
end)

test("typed table invalid reassignment should error", function()
    local analyzer = run(
        [[
            local tbl: {foo = 1} = {foo = 2}
        ]]
        ,"because 2 is not a subset of 1"
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
    local v = analyzer:GetValue("tbl", "runtime")

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

    local a = analyzer:GetValue("a", "runtime")
    local b = analyzer:GetValue("b", "runtime")

    equal(true, a:SubsetOf(b))
end)

test("indexing nil in a table should be allowed", function()
    local analyzer = run([[
        local tbl = {foo = true}
        local a = tbl.bar
    ]])

    equal("symbol", analyzer:GetValue("a", "runtime").Type)
    equal(nil, analyzer:GetValue("a", "runtime"):GetData())
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
        local a: {[string] = string} = {}
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
    equal(a:GetValue("a", "typesystem"):IsLiteral(), true)

    local a = run[[
        local type a = {a = 1, b = 2, c = {c = true}}
    ]]
    equal(a:GetValue("a", "typesystem"):IsLiteral(), true)
end)

test("is not literal", function()
    local a = run[[
        local type a = {a = number, [string] = boolean}
    ]]
    equal(a:GetValue("a", "typesystem"):IsLiteral(), false)

    local a = run[[
        local type a = {a = 1, b = 2, c = {c = boolean}}
    ]]
    equal(a:GetValue("a", "typesystem"):IsLiteral(), false)
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
        local x = {} as Foo
        
        type_assert(x:Test(1), _ as number)
        type_assert(x:GetPos(), _ as number)

        local func = x.Test
    ]]

    equal(a:GetValue("func", "runtime"):GetArguments():Get(1):Get("GetPos").Type, "function")
    equal(a:GetValue("func", "runtime"):GetArguments():Get(1):Get("Test").Type, "function")

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
        type function check_literal(tbl)
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
    local list: {[number] = any}
    list = {}
    type_assert(list, _ as {[number] = any})
]]


run[[
    type list = {[number] = any}
    list = {}
    type_assert(list, _ as {[number] = any})
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
    ]]):GetValue("a", "runtime")

    equal(a:Get("nested"):Get("a"), a)
    equal(a:Get("a"), a)
    equal(a:Get("a"), a:Get("nested"):Get("a"))
end)