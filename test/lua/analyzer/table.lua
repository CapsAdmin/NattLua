local T = require("test.helpers")
local run = T.RunCode

it("reassignment should work", function()
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

it("typed field should work", function()
    local analyzer = run[[
        local tbl: {foo = boolean} = {foo = true}
    ]]
    equal(true, analyzer:GetValue("tbl", "runtime"):Get("foo"):GetData())
end)

it("typed table invalid reassignment should error", function()
    local analyzer = run(
        [[
            local tbl: {foo = 1} = {foo = 2}
        ]]
        ,"because 2 is not a subset of 1"
    )
end)

it("typed table invalid reassignment should error", function()
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

it("typed table correct assignment not should error", function()
    run([[
        local tbl: {foo = true} = {foo = true}
        tbl.foo = true
    ]])
end)

it("self referenced tables should be equal", function()
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

it("indexing nil in a table should be allowed", function()
    local analyzer = run([[
        local tbl = {foo = true}
        local a = tbl.bar
    ]])

    equal("symbol", analyzer:GetValue("a", "runtime").Type)
    equal(nil, analyzer:GetValue("a", "runtime"):GetData())
end)

it("indexing nil in a table with a contract should error", function()
    run([[
        local tbl: {foo = true} = {foo = true}
        local a = tbl.bar
    ]], "\"bar\" is not a subset of \"foo\"")
end)

it("string: any", function()
    run([[
        local a: {[string] = any} = {} -- can assign a string to anything, (most common usage)
        a.lol = "aaa"
        a.lol2 = 2
        a.lol3 = {}
    ]])
end)

it("empty type table shouldn't be writable", function()
    run([[
        local a: {} = {}
        a.lol = true
    ]], "table has no definitions")
end)

it("wrong right hand type should error", function()
    run([[
        local {a,b} = nil
    ]], "expected a table on the right hand side, got")
end)

it("should error when key doesn't match the type", function()
    run([[
        local a: {[string] = string} = {}
        a.lol = "a"
        a[1] = "a"
    ]], "is not the same type as string")
end)

it("with typed numerically indexed table should error", function()
    run([[
        local tbl: {1,true,3} = {1, true, 3}
        tbl[2] = false
    ]], "false is not the same as true")
end)

it("which has no data but contract says it does should return what the contract says", function()
    run[[
        local tbl = {} as {[string] = 1}
        type_assert(tbl.foo, 1)
    ]]


    -- TODO: error or not error?
    run([[
        local tbl = {} as {[string] = 1}
        type_assert(tbl[true], nil)
    ]])
end)

it("is literal", function()
    local a = run[[
        local type a = {a = 1, b = 2}
    ]]
    equal(a:GetValue("a", "typesystem"):IsLiteral(), true)

    local a = run[[
        local type a = {a = 1, b = 2, c = {c = true}}
    ]]
    equal(a:GetValue("a", "typesystem"):IsLiteral(), true)
end)

it("is not literal", function()
    local a = run[[
        local type a = {a = number, [string] = boolean}
    ]]
    equal(a:GetValue("a", "typesystem"):IsLiteral(), false)

    local a = run[[
        local type a = {a = 1, b = 2, c = {c = boolean}}
    ]]
    equal(a:GetValue("a", "typesystem"):IsLiteral(), false)
end)

it("self reference", function()
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

        type_assert<(b.bar, true)>
        type_assert<(b.foo, b)>
    ]]
end)

it("table extending table", function()
    run[[
        local type A = {
            Foo = true,
        }

        local type B = {
            Bar = false,
        }

        type_assert<(A extends B, {Foo = true, Bar = false})>
    ]]
end)

it("table + table", function()
    run[[
        local type A = {
            Foo = true,
            Bar = 1,
        }

        local type B = {
            Bar = false,
        }

        type_assert<(A + B, {Foo = true, Bar = false})>
    ]]
end)

it("index literal table with string", function()
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