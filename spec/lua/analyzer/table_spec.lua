local T = require("spec.lua.helpers")
local run = T.RunCode

describe("table", function()
    it("reassignment should work", function()
        local analyzer = run[[
            local tbl = {}
            tbl.foo = true
            tbl.foo = false
        ]]

        local tbl = analyzer:GetValue("tbl", "runtime")

        assert.equal(false, tbl:Get("foo"):GetData())

        local analyzer = run[[
            local tbl = {foo = true}
            tbl.foo = false
        ]]

        local tbl = analyzer:GetValue("tbl", "runtime")
        assert.equal(false, tbl:Get("foo"):GetData())
    end)

    it("typed field should work", function()
        local analyzer = run[[
            local tbl: {foo = boolean} = {foo = true}
        ]]
        assert.equal(true, analyzer:GetValue("tbl", "runtime"):Get("foo"):GetData())
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

        assert.equal(true, a:SubsetOf(b))
    end)

    it("indexing nil in a table should be allowed", function()
        local analyzer = run([[
            local tbl = {foo = true}
            local a = tbl.bar
        ]])

        assert.equal("nil", analyzer:GetValue("a", "runtime").type)
    end)

    it("indexing nil in a table with a contract should error", function()
        run([[
            local tbl: {foo = true} = {foo = true}
            local a = tbl.bar
        ]], "\"bar\" is not a subset of any of the keys in ")
    end)

    pending("string: any", function()
        run([[
            local a: {[string] = any} = {} -- can assign a string to anything, (most common usage)
            a.lol = "aaa"
            a.lol2 = 2
            a.lol3 = {}
            a[1] = {}
        ]])
    end)

    it("nested tables should work", function()
        local analyzer = run[[
            interface a {
                foo = {
                    bar = number
                }
            }

            local tbl: a = {foo = {bar = 1}}
        ]]

        local tbl = analyzer:GetValue("tbl", "runtime")
        print(tbl)
    end)
end)