local T = require("test.helpers")
local run = T.RunCode

test("logic operators", function()
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

test("boolean and or logic", function() -- and or
    -- when false, or returns its second argument
    run"type_assert(nil or false, false)"
    run"type_assert(false or nil, nil)"

    -- when true, or returns its first argument
    run"type_assert(1 or false, 1)"
    run"type_assert(true or nil, true)"

    run"type_assert(nil or {}, {})"

    -- boolean without any data can be true and false at the same time
    run"type_assert((_ as boolean) or (1), _ as true | 1)"

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

        for _, v in pairs(allcases(4)) do
            run("type_assert("..tostring(v[1])..", "..tostring(v[2])..")")
        end
    end
end)

test("bit operations", function()
    run[[
        for i=1,100 do
            assert(bit.tobit(i+0x7fffffff) < 0)
        end
        for i=1,100 do
            assert(bit.tobit(i+0x7fffffff) <= 0)
        end
    ]]
end)

test("string comparisons", function()
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

test("object equality", function()
    run[[
        local function obj_eq(a, b)
            type_assert(a==b, true)
            type_assert(a~=b, false)
        end

        local function obj_ne(a, b)
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
        type_assert(t==t2, _ as false)
        type_assert(t~=t2, _ as true)
        obj_ne(t, 1)
        obj_ne(t, "")
    ]]
end)
