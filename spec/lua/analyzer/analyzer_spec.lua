local oh = require("oh")
local C = oh.Code

local function run(code, expect_error)
    local code_data = oh.Code(code, nil, nil, 3)
    local ok, err = code_data:Analyze()

    if expect_error then
        if not err then
            error("expected error, got\n\n\n[" .. tostring(ok) .. ", " .. tostring(err) .. "]")
        elseif type(expect_error) == "string" and not err:find(expect_error) then
            error("expected error " .. expect_error .. " got\n\n\n" .. err)
        end
    else
        if not ok then
            code_data = C(code_data.code)
            local ok, err2 = code_data:Analyze(true)
            print(code_data.code)
            error(err)
        end
    end

    return code_data.Analyzer
end

describe("analyzer", function()
    it("runtime scopes should work", function()
        local v = run("local a = 1"):GetValue("a", "runtime")
        assert.equal(v.Type, "object")
        assert.equal(true, v:IsType("number"))
    end)

    it("comment types", function()
        run([[
            --: local type a = 1
            type_assert(a, 1)
        ]])
    end)

    it("branching", function()
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

    it("runtime block scopes should work", function()

        local analyzer = run("do local a = 1 end")
        assert.equal(nil, analyzer:GetValue("a", "runtime"))
        assert.equal(1, analyzer:GetScope().children[1].upvalues.runtime.map.a.data:GetData()) -- TODO: awkward access

        local v = run[[
            local a = 1
            do
                local a = 2
            end
        ]]:GetValue("a", "runtime")

        assert.equal(v:GetData(), 1)
    end)

    it("runtime reassignment should work", function()
        local v = run[[
            local a = 1
            do
                a = 2
            end
        ]]:GetValue("a", "runtime")

        assert.equal(v:GetData(), 2)
    end)

    it("typesystem differs from runtime", function()
        local analyzer = run[[
            local a = 1
            local type a = 2
        ]]

        assert.equal(analyzer:GetValue("a", "runtime"):GetData(), 1)
        assert.equal(analyzer:GetValue("a", "typesystem"):GetData(), 2)
    end)

    it("global types should work", function()
        local analyzer = run[[
            do
                type a = 2
            end
            local b: a
        ]]

        assert.equal(2, analyzer:GetValue("b", "runtime"):GetData())
    end)

    it("constant types should work", function()
        local analyzer = run[[
            local a: 1
            local b: number
        ]]

        assert.equal(true, analyzer:GetValue("a", "runtime"):IsConst())
        assert.equal(false, analyzer:GetValue("b", "runtime"):IsConst())
    end)

    -- literal + vague = vague
    it("1 + number = number", function()
        local analyzer = run[[
            local a: 1
            local b: number
            local c = a + b
        ]]

        local v = analyzer:GetValue("c", "runtime")
        assert.equal(v.Type, "object")
        assert.equal(true, v:IsType("number"))
        assert.equal(false, v:IsConst())
    end)

    it("1 + 2 = 3", function()
        local analyzer = run[[
            local a = 1
            local b = 2
            local c = a + b
        ]]

        local v = analyzer:GetValue("c", "runtime")
        assert.equal(v.Type, "object")
        assert.equal(true, v:IsType("number"))
        assert.equal(3, v:GetData())
    end)

    it("function return value should work", function()
        local analyzer = run[[
            local function test()
                return 1+2+3
            end
            local a = test()
        ]]

        local v = analyzer:GetValue("a", "runtime")
        assert.equal(6, v:GetData())
    end)

    it("multiple function return values should work", function()
        local analyzer = run[[
            local function test()
                return 1,2,3
            end
            local a,b,c = test()
        ]]

        assert.equal(1, analyzer:GetValue("a", "runtime"):GetData())
        assert.equal(2, analyzer:GetValue("b", "runtime"):GetData())
        assert.equal(3, analyzer:GetValue("c", "runtime"):GetData())
    end)


    it("scopes shouldn't leak", function()
        local analyzer = run[[
            local a = {}
            function a:test(a, b)
                return nil, a+b
            end
            local _, a = a:test(1, 2)
        ]]

        assert.equal(3, analyzer:GetValue("a", "runtime"):GetData())
    end)

    it("explicitly annotated variables need to be set properly", function()
        local analyzer = run[[
            local a: number | string = 1
        ]]
    end)

    it("functions can modify parent scope", function()
        local analyzer = run[[
            local a = 1
            local c = a
            local function test()
                a = 2
            end
            test()
        ]]

        assert.equal(2, analyzer:GetValue("a", "runtime"):GetData())
        assert.equal(1, analyzer:GetValue("c", "runtime"):GetData())
    end)

    it("uncalled functions should be called", function()
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

        assert.equal(true, lib:Get("foo1"):GetArguments().data[1]:IsType("number"))
        assert.equal(true, lib:Get("foo1"):GetArguments().data[2]:IsType("number"))
        assert.equal(true, lib:Get("foo1"):GetReturnTypes().data[1]:IsType("number"))

        assert.equal(true, lib:Get("foo2"):GetArguments().data[1]:IsType("number"))
        assert.equal(true, lib:Get("foo2"):GetArguments().data[2]:IsType("number"))
        assert.equal(true, lib:Get("foo2"):GetReturnTypes().data[1]:IsType("number"))
    end)

    it("should convert binary numbers to numbers", function()
        local analyzer = run[[
            local a = 0b01
        ]]
        assert.equal(1, analyzer:GetValue("a", "runtime"):GetData())
    end)

    it("undefined types should error", function()
        run([[local a: ASDF = true]], "cannot be nil")
    end)

    it("type functions should return a tuple with types", function()
        local analyzer = run([[
            local type test = function()
                return 1,2,3
            end

            local type a,b,c = test()
        ]])

        assert.equal(1, analyzer:GetValue("a", "typesystem"):GetData())
        assert.equal(2, analyzer:GetValue("b", "typesystem"):GetData())
        assert.equal(3, analyzer:GetValue("c", "typesystem"):GetData())
    end)

    it("type should be able to error", function()
        run([[
            local type test = function()
                error("test")
            end

            test()
        ]], "test")
    end)

    it("exclude type function should work", function()
        run([[
            type Exclude = function(T, U)
                T:RemoveElement(U)
                return T
            end

            local a: Exclude<1|2|3, 2>

            type_assert(a, _ as 1|3)
        ]])

        run([[
            type Exclude = function(T, U)
                T:RemoveElement(U)
                return T
            end

            local a: Exclude<1|2|3, 2>

            type_assert(a, _ as 11|31)
        ]], "expected 11 | 31 got 1 | 3")
    end)

    pending("what", function()
        run[=[
            local a = 1
            function b(lol: number)
                if lol == 1 then return "foo" end
                return lol + 4, true
            end
            local d = b(2)
            local d = b(a)

            local lol: {a = boolean |nil, Foo = (function():nil) | nil} = {a = nil, Foo = nil}
            lol.a = true

            function lol:Foo(foo, bar)
                local a = self.a
            end

            --local lol: string[] = {}

            --local a = table.concat(lol)
        ]=]
    end)

    pending("lists should work", function()
        local analyzer = run([[
            type Array = function(T, L)
                return types.Create("list", {type = T, values = {}, length = L.data})
            end

            local list: Array<number, 3> = {1, 2, 3}
        ]])
        print(analyzer:GetValue("list", "runtime"))
    end)

    pending("expected errors", function()
        run([[require("adawdawddwaldwadwadawol")]], "unable to find module")

        run([[local a = 1 a()]], "1 cannot be called")

        run([[
                local {a,b} = nil
            ]], "expected a table on the right hand side, got")
        run([[
                local a: {[string] = string} = {}
                a.lol = "a"
                a[1] = "a"
            ]], "invalid key number.-expected string")
        run([[
                local a: {[string] = string} = {}
                a.lol = 1
            ]], "invalid value number.-expected string")
        run([[
                local a: {} = {}
                a.lol = true
            ]], "invalid key string")
        run([[
                local tbl: {1,true,3} = {1, true, 3}
                tbl[2] = false
            ]], "invalid value boolean.-expected.-true")
        run([[
                local tbl: {1,true,3} = {1, false, 3}
            ]], "expected .- but the right hand side is ")
        run([[
                assert(1 == 2, "lol")
            ]],"lol")

        run([[
            local a: {} = {}
            a.lol = true
        ]],"invalid key")

        run([[
            local a = 1
            a.lol = true
        ]],"undefined set:")

        run([[local a = 1; a = a.lol]],"undefined get:")
        run([[local a = 1 + true]], "no operator for.-number.-%+.-boolean")

    end)
end)