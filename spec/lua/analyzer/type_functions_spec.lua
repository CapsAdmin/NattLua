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

describe("type functions", function()

    it("should return a tuple with types", function()
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

    it("should be able to error", function()
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

    pending("next should work", function()
        run[[
            local k,v = next({k = 1})
            type_assert(k, nil as "k")
            type_assert(v, nil as 1)
        ]]
    end)

    pending("math.floor", function()
        R[[
            type_assert(math.floor(1), 1)
        ]]
    end)
end)