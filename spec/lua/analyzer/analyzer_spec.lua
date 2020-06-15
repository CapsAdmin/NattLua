local T = require("spec.lua.helpers")
local run = T.RunCode

describe("analyzer", function()
    it("type_assert works", function()
        run("type_assert(1, 2)", "expected.-2 got 1")
        run("type_assert(nil as 1|2, 1)", "expected.-1")

        run"type_assert(not true, false)"
        run"type_assert(not 1, false)"
        run"type_assert(nil==nil, true)"
    end)

    it("logic operators", function()
        run[[
            local function lt(x, y)
                if x < y then return true else return false end
            end

            local function le(x, y)
                if x <= y then return true else return false end
            end

            local function gt(x, y)
                if x > y then return true else return false end
            end

            local function ge(x, y)
                if x >= y then return true else return false end
            end

            local function eq(x, y)
                if x == y then return true else return false end
            end

            local function ne(x, y)
                if x ~= y then return true else return false end
            end


            local function ltx1(x)
                if x < 1 then return true else return false end
            end

            local function lex1(x)
                if x <= 1 then return true else return false end
            end

            local function gtx1(x)
                if x > 1 then return true else return false end
            end

            local function gex1(x)
                if x >= 1 then return true else return false end
            end

            local function eqx1(x)
                if x == 1 then return true else return false end
            end

            local function nex1(x)
                if x ~= 1 then return true else return false end
            end


            local function lt1x(x)
                if 1 < x then return true else return false end
            end

            local function le1x(x)
                if 1 <= x then return true else return false end
            end

            local function gt1x(x)
                if 1 > x then return true else return false end
            end

            local function ge1x(x)
                if 1 >= x then return true else return false end
            end

            local function eq1x(x)
                if 1 == x then return true else return false end
            end

            local function ne1x(x)
                if 1 ~= x then return true else return false end
            end

            do --- 1,2
                local x,y = 1,2

                type_assert(x<y,	true)
                type_assert(x<=y,	true)
                type_assert(x>y,	false)
                type_assert(x>=y,	false)
                type_assert(x==y,	false)
                type_assert(x~=y,	true)

                type_assert(1<y,	true)
                type_assert(1<=y,	true)
                type_assert(1>y,	false)
                type_assert(1>=y,	false)
                type_assert(1==y,	false)
                type_assert(1~=y,	true)

                type_assert(x<2,	true)
                type_assert(x<=2,	true)
                type_assert(x>2,	false)
                type_assert(x>=2,	false)
                type_assert(x==2,	false)
                type_assert(x~=2,	true)

                type_assert(lt(x,y),	true)
                type_assert(le(x,y),	true)
                type_assert(gt(x,y),	false)
                type_assert(ge(x,y),	false)
                type_assert(eq(y,x),	false)
                type_assert(ne(y,x),	true)
            end

            do --- 2,1
                local x,y = 2,1

                type_assert(x<y,	false)
                type_assert(x<=y,	false)
                type_assert(x>y,	true)
                type_assert(x>=y,	true)
                type_assert(x==y,	false)
                type_assert(x~=y,	true)

                type_assert(2<y,	false)
                type_assert(2<=y,	false)
                type_assert(2>y,	true)
                type_assert(2>=y,	true)
                type_assert(2==y,	false)
                type_assert(2~=y,	true)

                type_assert(x<1,	false)
                type_assert(x<=1,	false)
                type_assert(x>1,	true)
                type_assert(x>=1,	true)
                type_assert(x==1,	false)
                type_assert(x~=1,	true)

                type_assert(lt(x,y),	false)
                type_assert(le(x,y),	false)
                type_assert(gt(x,y),	true)
                type_assert(ge(x,y),	true)
                type_assert(eq(y,x),	false)
                type_assert(ne(y,x),	true)
            end

            do --- 1,1
                local x,y = 1,1

                type_assert(x<y,	false)
                type_assert(x<=y,	true)
                type_assert(x>y,	false)
                type_assert(x>=y,	true)
                type_assert(x==y,	true)
                type_assert(x~=y,	false)

                type_assert(1<y,	false)
                type_assert(1<=y,	true)
                type_assert(1>y,	false)
                type_assert(1>=y,	true)
                type_assert(1==y,	true)
                type_assert(1~=y,	false)

                type_assert(x<1,	false)
                type_assert(x<=1,	true)
                type_assert(x>1,	false)
                type_assert(x>=1,	true)
                type_assert(x==1,	true)
                type_assert(x~=1,	false)

                type_assert(lt(x,y),	false)
                type_assert(le(x,y),	true)
                type_assert(gt(x,y),	false)
                type_assert(ge(x,y),	true)
                type_assert(eq(y,x),	true)
                type_assert(ne(y,x),	false)
            end

            do --- 2
                type_assert(lt1x(2),	true)
                type_assert(le1x(2),	true)
                type_assert(gt1x(2),	false)
                type_assert(ge1x(2),	false)
                type_assert(eq1x(2),	false)
                type_assert(ne1x(2),	true)

                type_assert(ltx1(2),	false)
                type_assert(lex1(2),	false)
                type_assert(gtx1(2),	true)
                type_assert(gex1(2),	true)
                type_assert(eqx1(2),	false)
                type_assert(nex1(2),	true)
            end

            do --- 1
                type_assert(lt1x(1),	false)
                type_assert(le1x(1),	true)
                type_assert(gt1x(1),	false)
                type_assert(ge1x(1),	true)
                type_assert(eq1x(1),	true)
                type_assert(ne1x(1),	false)

                type_assert(ltx1(1),	false)
                type_assert(lex1(1),	true)
                type_assert(gtx1(1),	false)
                type_assert(gex1(1),	true)
                type_assert(eqx1(1),	true)
                type_assert(nex1(1),	false)
            end

            do --- 0
                type_assert(lt1x(0),	false)
                type_assert(le1x(0),	false)
                type_assert(gt1x(0),	true)
                type_assert(ge1x(0),	true)
                type_assert(eq1x(0),	false)
                type_assert(ne1x(0),	true)

                type_assert(ltx1(0),	true)
                type_assert(lex1(0),	true)
                type_assert(gtx1(0),	false)
                type_assert(gex1(0),	false)
                type_assert(eqx1(0),	false)
                type_assert(nex1(0),	true)
            end
        ]]
    end)

    it("boolean and or logic", function() -- and or
        -- when false, or returns its second argument
        run"type_assert(nil or false, false)"
        run"type_assert(false or nil, nil)"

        -- when true, or returns its first argument
        run"type_assert(1 or false, 1)"
        run"type_assert(true or nil, true)"

        run"type_assert(nil or {}, {})"

        -- boolean without any data can be true and false at the same time
        run"type_assert((_ as boolean) or (1), _ as boolean | 1)"

        -- when false and returns its first argument
        run"type_assert(false and true, false)"
        run"type_assert(true and nil, nil)"

        -- when true and returns its second argument
        -- ????

        -- smoke test
        run"type_assert(((1 or false) and true) or false, true)"

        do --- allcases
            local basiccases = {
                {"nil", nil},
                {"false", false},
                {"true", true},
                {"10", 10},
            }

            local mem = {basiccases}    -- for memoization

            local function allcases (n)
                if mem[n] then return mem[n] end
                local res = {}
                -- include all smaller cases
                for _, v in ipairs(allcases(n - 1)) do
                    res[#res + 1] = v
                end
                for i = 1, n - 1 do
                    for _, v1 in ipairs(allcases(i)) do
                        for _, v2 in ipairs(allcases(n - i)) do
                            res[#res + 1] = {
                                "(" .. v1[1] .. " and " .. v2[1] .. ")",
                                v1[2] and v2[2]
                            }
                            res[#res + 1] = {
                                "(" .. v1[1] .. " or " .. v2[1] .. ")",
                                v1[2] or v2[2]
                            }
                        end
                    end
                end
                mem[n] = res   -- memoize
                return res
            end
            local code = {}
            for _, v in pairs(allcases(4)) do
                table.insert(code, "type_assert("..tostring(v[1])..", "..tostring(v[2])..")")
            end

            run(table.concat(code, "\n"))
        end
    end)

    pending("pcall", function()
        run[[
            do --- pcall
                assert(not pcall(function()
                    local a, b = 10.5, nil
                    return a < b
                end))
            end
        ]]
    end)

    it("bit operations", function()
        run[[
            for i=1,100 do
                assert(bit.tobit(i+0x7fffffff) < 0)
            end
            for i=1,100 do
                assert(bit.tobit(i+0x7fffffff) <= 0)
            end
        ]]
    end)

    it("string comparisons", function()
        run[[
            do
                local a = "\255\255\255\255"
                local b = "\1\1\1\1"

                assert(a > b)
                assert(a > b)
                assert(a >= b)
                assert(b <= a)
            end

            do --- String comparisons:
                local function str_cmp(a, b, lt, gt, le, ge)
                    assert(a<b == lt)
                    assert(a>b == gt)
                    assert(a<=b == le)
                    assert(a>=b == ge)
                    assert((not (a<b)) == (not lt))
                    assert((not (a>b)) == (not gt))
                    assert((not (a<=b)) == (not le))
                    assert((not (a>=b)) == (not ge))
                end

                local function str_lo(a, b)
                    str_cmp(a, b, true, false, true, false)
                end

                local function str_eq(a, b)
                    str_cmp(a, b, false, false, true, true)
                end

                local function str_hi(a, b)
                    str_cmp(a, b, false, true, false, true)
                end

                str_lo("a", "b")
                str_eq("a", "a")
                str_hi("b", "a")

                str_lo("a", "aa")
                str_hi("aa", "a")

                str_lo("a", "a\0")
                str_hi("a\0", "a")
            end
        ]]
    end)

    it("object equality", function()
        run[[
            local function obj_eq(a: any, b: any)
                type_assert(a==b, true)
                type_assert(a~=b, false)
            end

            local function obj_ne(a: any, b: any)
                type_assert(a==b, false)
                type_assert(a~=b, true)
            end

            obj_eq(nil, nil)
            obj_ne(nil, false)
            obj_ne(nil, true)

            obj_ne(false, nil)
            obj_eq(false, false)
            obj_ne(false, true)

            obj_ne(true, nil)
            obj_ne(true, false)
            obj_eq(true, true)

            obj_eq(1, 1)
            obj_ne(1, 2)
            obj_ne(2, 1)

            obj_eq("a", "a")
            obj_ne("a", "b")
            obj_ne("a", 1)
            obj_ne(1, "a")

            local t, t2 = {}, {}
            obj_eq(t, t)
            obj_ne(t, t2)
            obj_ne(t, 1)
            obj_ne(t, "")
        ]]
    end)

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

    it("default declaration is const", function()
        local analyzer = run([[
            local a = 1
            local t = {k = 1}
            local b = t.k
        ]])
        assert(analyzer:GetValue("a", "runtime"):IsConst())
        assert(analyzer:GetValue("b", "runtime"):IsConst())
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