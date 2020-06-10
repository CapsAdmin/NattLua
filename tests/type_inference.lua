-- R"type_assert((nil as boolean) or 1, (nil as boolean) | 1)"


local oh = require("oh")
local C = oh.Code

local function R(code, expect_error)
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
            local ok, err2 = C(code_data.code):Analyze(true)
            print(code_data.code)
            error(err)
        end
    end
end

-- make sure type_assert works
R("type_assert(1, 2)", "expected.-2 got 1")
R("type_assert(nil as 1|2, 1)", "expected.-1")

R"type_assert(not true, false)"
R"type_assert(not 1, false)"
R"type_assert(nil==nil, true)"


R[[
    local function test(a,b)

    end

    test(true, true)
    test(false, false)

    --type_assert(test, _ as (function(a: false|true, b: false|true):))
]]
R[[
    local function test(a: any,b: any)

    end

    test(true, true)
    test(false, false)

    type_assert(test, _ as (function(a: any, b: any):))
]]


R[[
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

      do --- pcall
        assert(not pcall(function()
          local a, b = 10.5, nil
          return a < b
        end))
      end

      do --- bit +bit
        for i=1,100 do
          assert(bit.tobit(i+0x7fffffff) < 0)
        end
        for i=1,100 do
          assert(bit.tobit(i+0x7fffffff) <= 0)
        end
      end

      do --- string 1 255
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

      do --- obj_eq/ne
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
      end
]]

do -- and or
    -- when false, or returns its second argument
    R"type_assert(nil or false, false)"
    R"type_assert(false or nil, nil)"

    -- when true, or returns its first argument
    R"type_assert(1 or false, 1)"
    R"type_assert(true or nil, true)"

    R"type_assert(nil or {}, {})"

    -- boolean without any data can be true and false at the same time
    R"type_assert((_ as boolean) or (1), _ as boolean | 1)"

    -- when false and returns its first argument
    R"type_assert(false and true, false)"
    R"type_assert(true and nil, nil)"

    -- when true and returns its second argument
    -- ????

    -- smoke test
    R"type_assert(((1 or false) and true) or false, true)"

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
            R("type_assert("..tostring(v[1])..", "..tostring(v[2])..")")
        end
    end
end

do -- assignment
    R[[
        local a
        type_assert(a, nil)
    ]]

    R[[
        local a: boolean
        type_assert(a, _ as boolean)
    ]]


    R[[
        a = nil
        -- todo, if any calls don't happen here then it's probably nil?
        type_assert(a, _ as nil)
    ]]

    R[[
        local a = {}
        a[5] = 5
        type_assert(a[5], 5)
    ]]

    R[[
        local a = {}

        local i = 0
        function test(n)
            i = i + 1

            if i ~= n then
                local test = function(n) TPRINT(n) return n end
                a[test(1)], a[test(2)], a[test(3)] = test(4), test(5), test(6)
                type_assert(i, n)
            end

            return n
        end

        -- test should be executed in the numeric order

        a[test(1)], a[test(2)], a[test(3)] = test(4), test(5), test(6)
    ]]


    R[[
        local function test(...)
            return 1,2,...
        end

        local a,b,c = test(3)

        type_assert(a,1)
        type_assert(b,2)
        type_assert(c,3)
    ]]

    R[[
        local a, b, c
        a, b, c = 0, 1
        type_assert(a, 0)
        type_assert(b, 1)
        type_assert(c, nil)
        a, b = a+1, b+1, a+b
        type_assert(a, 1)
        type_assert(b, 2)
        a, b, c = 0
        type_assert(a, 0)
        type_assert(b, nil)
        type_assert(c, nil)
    ]]

    R[[
        a, b, c = 0, 1
        type_assert(a, 0)
        type_assert(b, 1)
        type_assert(c, nil)
        a, b = a+1, b+1, a+b
        type_assert(a, 1)
        type_assert(b, 2)
        a, b, c = 0
        type_assert(a, 0)
        type_assert(b, nil)
        type_assert(c, nil)
    ]]
    R[[
        local a = {}
        local i = 3

        i, a[i] = i+1, 20

        type_assert(i, 4)
        type_assert(a[3], 20)
    ]]
    R[[
        a = {}
        i = 3
        i, a[i] = i+1, 20
        type_assert(i, 4)
        type_assert(a[3], 20)
    ]]
end

R[[
    local z1, z2
    local function test(i)
        local function f() return i end
        z1 = z1 or f
        z2 = f
    end

    test(1)
    test(2)

    --type_assert(z1(), 1)
    type_assert(z2(), 2)
]]

--local numbers = {-1,-0.5,0,0.5,1,math.huge,0/0}


R"type_assert(1, 1)"
R"type_assert(-1, -1)"
R"type_assert(-0.5, -0.5)"
R"type_assert(0, 0)"

--- exp
R[[
    type_assert(1e5, 100000)
    type_assert(1e+5, 100000)
    type_assert(1e-5, 0.00001)
]]

--- hex exp +hexfloat !lex
R[[
    type_assert(0xe+9, 23)
    type_assert(0xep9, 7168)
    type_assert(0xep+9, 7168)
    type_assert(0xep-9, 0.02734375)
]]


R"type_assert(1-1, 0)"
R"type_assert(1+1, 2)"
R"type_assert(2*3, 6)"
R"type_assert(2^3, 8)"
R"type_assert(3%3, 0)"
R"type_assert(-1*2, -2)"
R"type_assert(1/2, 0.5)"

R"type_assert(1/2, 0.5)"

R"type_assert(0b10 | 0b01, 0b11)"
R"type_assert(0b10 & 0b10, 0b10)"
R"type_assert(0b10 & 0b10, 0b10)"

--R"type_assert(0b10 >> 1, 0b01)"
--R"type_assert(0b01 << 1, 0b10)"
R"type_assert(~0b01, -2)"

R"type_assert('a'..'b', 'ab')"
R"type_assert('a'..'b'..'c', 'abc')"
R"type_assert(1 .. '', nil as '1')"
R"type_assert('ab'..(1)..'cd'..(1.5), 'ab1cd1.5')"



R[[ --- tnew
    local a = nil
    local b = {}
    local t = {[true] = a, [false] = b or 1}
    type_assert(t[true], nil)
    type_assert(t[false], b)
]]

R[[ --- tdup
    local b = {}
    local t = {[true] = nil, [false] = b or 1}
    type_assert(t[true], nil)
    type_assert(t[false], b)
]]


R[[
    do --- tnew
        local a = nil
        local b = {}
        local t = {[true] = a, [false] = b or 1}
        assert(t[true] == nil)
        assert(t[false] == b)
    end

    do --- tdup
        local b = {}
        local t = {[true] = nil, [false] = b or 1}
        assert(t[true] == nil)
        assert(t[false] == b)
    end
]]

R[[
    local a = 1
    type_assert(a, nil as 1)
]]

R[[
    local a = {a = 1}
    type_assert(a.a, nil as 1)
]]

R[[
    local a = {a = {a = 1}}
    type_assert(a.a.a, nil as 1)
]]

R[[
    local a = {a = 1}
    a.a = nil
    type_assert(a.a, nil)
]]

R[[
    local a = {}
    a.a = 1
    type_assert(a.a, nil as 1)
]]

R[[
    local a = ""
    type_assert(a, nil as "")
]]
R[[
    local type a = number
    type_assert(a, _ as number)
]]

R[[
    local a
    a = 1
    type_assert(a, 1)
]]
R[[
    local a = {}
    a.foo = {}

    local c = 0

    function a:bar()
        type_assert(self, a)
        c = 1
    end

    a:bar()

    type_assert(c, 1)
]]
R[[
    local function test()

    end

    type_assert(test, nil as function():)
]]
R[[
    local a = 1
    repeat
        type_assert(a, 1)
    until false
]]
R[[
    local c = 0
    for i = 1, 10, 2 do
        type_assert_superset(i, nil as number)
        if i == 1 then
            c = 1
            break
        end
    end
    type_assert(c, 1)
]]
R[[
    local a = 0
    while false do
        a = 1
    end
    type_assert(a, 0)
]]
R[[
    local function lol(a,b,c)
        if true then
            return a+b+c
        elseif true then
            return true
        end
        a = 0
        return a
    end
    local a = lol(1,2,3)

    type_assert(a, 6)
]]
R[[
    local a = 1+2+3+4
    local b = nil

    local function print(foo)
        return foo
    end

    if a then
        b = print(a+10)
    end

    type_assert(b, 20)
    type_assert(a, 10)
]]
R[[
    local a
    a = 2

    if true then
        local function foo(lol)
            return foo(lol), nil
        end
        local complex = foo(a)
        type_assert_superset(foo, nil as function(_:any, _:nil):number )
    end
]]
R[[
    b = {}
    b.lol = 1

    local a = b

    local function foo(tbal)
        return tbal.lol + 1
    end

    local c = foo(a)

    type_assert(c, 2)
]]
R[[
    local META = {}
    META.__index = META

    function META:Test(a,b,c)
        return 1+c,2+b,3+a
    end

    local a,b,c = META:Test(1,2,3)

    local ret

    if someunknownglobal as any then
        ret = a+b+c
    end

    type_assert(ret, 12)
]]
R[[
    local function test(a)
        if a then
            return 1
        end

        return false
    end

    local res = test(true)

    if res then
        local a = 1 + res

        type_assert(a, 2)
    end
]]
R[[
    local a = 1337
    for i = 1, 10 do
        type_assert(i, 1)
        if i == 15 then
            a = 7777
            break
        end
    end
    type_assert(a, 1337)
]]
R[[
    local function lol(a, ...)
        local lol,foo,bar = ...

        if a == 1 then return 1 end
        if a == 2 then return {} end
        if a == 3 then return "", foo+2,3 end
    end

    local a,b,c = lol(3,1,2,3)

    type_assert(a, "")
    type_assert(b, 4)
    type_assert(c, 3)
]]
R[[
    function foo(a, b) return a+b end

    local a = foo(1,2)

    type_assert(a, 3)
]]
R[[
local   a,b,c = 1,2,3
        d,e,f = 4,5,6

type_assert(a, 1)
type_assert(b, 2)
type_assert(c, 3)

type_assert(d, 4)
type_assert(e, 5)
type_assert(f, 6)

local   vararg_1 = ... as any
        vararg_2 = ... as any

type_assert(vararg_1, _ as any)
type_assert(vararg_2, _ as any)

local function test(...)
    return a,b,c, ...
end

A, B, C, D = test(), 4

type_assert(A, 1)
type_assert(B, 2)
type_assert(C, 3)
type_assert(D, nil as []) -- THIS IS WRONG, tuple of any?

local z,x,y,æ,ø,å = test(4,5,6)
local novalue

type_assert(z, 1)
type_assert(x, 2)
type_assert(y, 3)
type_assert(æ, 4)
type_assert(ø, 5)
type_assert(å, 6)

]]
R[[
local a = {b = {c = {}}}
a.b.c = 1
]]
R[[
    local a = function(b)
        if b then
            return true
        end
        return 1,2,3
    end

    a()
    a(true)

]]
R[[
    function string(ok: boolean)
        if ok then
            return 2
        else
            return "hello"
        end
    end

    string(true)
    local ag = string(false)

    type_assert(ag, "hello")

]]
R[[
    local foo = {lol = 30}
    function foo:bar(a)
        return a+self.lol
    end

    type_assert(foo:bar(20), 50)

]]
R[[
    function prefix (w1, w2)
        return w1 .. ' ' .. w2
    end

    type_assert(prefix("hello", "world"), "hello world")
]]
R[[
    local function test(max: number)
        for i = 1, max do
            if i == 20 then
                return false
            end

            if i == 5 then
                return true
            end
        end
        return "lol"
    end

    local a = test(20)
    local b = test(5)
    local c = test(1)

    local LOL = a

    type_assert(a, false)
    type_assert(b, true)
    type_assert(c, "lol")
]]
R[[
    local func = function()
        local a = 1

        return function()
            return a
        end
    end

    local f = func()

    type_assert(f(), 1)
]]
R[[
    function prefix (w1, w2)
        return w1 .. ' ' .. w2
    end

    local w1,w2 = "foo", "bar"
    local statetab = {["foo bar"] = 1337}

    local test = statetab[prefix(w1, w2)]
    type_assert(test, 1337)
]]
R[[
    local function test(a)
        --if a > 10 then return a end
        return test(a+1)
    end

    type_assert(test(1), nil as any)
]]
R[[
    local function test(a): number
        if a > 10 then return a end
        return test(a+1)
    end

    type_assert(test(1), nil as number)
]]
R[[
    local a: string | number = 1

    local type test = function(a: number, b: string): boolean, number

    local foo,bar = test(1, "")

    type_assert(foo, nil as boolean)
    type_assert(bar, nil as number)
]]
R[[
    do
        type x = boolean | number
    end

    type c = x
    local a: c
    type b = {foo = a as any}
    local c: function(a: number, b:number): b, b

    type_assert_superset(c, nil as function(_:table, _:table): number, number)

]]
R[[
    local function test(a:number,b: number)
        return a + b
    end

    type_assert_superset(test, nil as function(_:number, _:number): number)
]]
R[[
    type lol = number

    interface math {
        sin = function(a: lol, b: string): lol
        cos = function(a: string): lol
        cos = function(a: number): lol
    }

    interface math {
        lol = function(): lol
    }


    local a = math.sin(1, "")
    local b = math.lol() -- support overloads

    type_assert(a, nil as number)
    type_assert(b, nil as number)
]]
R[[
    interface foo {
        a = number
        b = {
            str = string,
        }
    }

    local b: foo = {a=1, b={str="lol"}}
    local c = b.a
    local d = b.b.str

    type_assert(b, nil as foo)
]]
R[[
  --  local a: (string|number)[] = {"", ""}
  --  a[1] = ""
  --  a[2] = 1
]]
R[[
    interface foo {
        bar = function(a: boolean, b: number): true
        bar = function(a: number): false
    }

    local a = foo.bar(true, 1)
    local b = foo.bar(1)

    type_assert(a, nil as [true])
    type_assert(b, nil as [false])
]]
R[[
    local a: string = "1"
    type a = string | number | (boolean | string)

    type type_func = function(a,b,c) return types.Create("string"), types.Create("number") end
    local a, b = type_func(a,2,3)
    type_assert(a, _ as string)
    type_assert(b, _ as number)
]]
R[[
    type Array = function(T, L)
        return types.Create("list", {values = T.name, length = L.data})
    end

    type Exclude = function(T, U)
        T:RemoveElement(U)
        return T
    end

    local a: Exclude<1|2|3, 2> = 1
    type_assert(a, _ as 1|3)

    local list: Array<number, 3> = {1, 2, 3}
    type_assert_superset(list, _ as number[3])
]]
R[[
    function pairs(t)
        return next, t, nil
    end

    do
        local function iter(a, i)
            i = i + 1
            local v = a[i]
            if v then
                return i, v
            end
        end

        function ipairs(a)
            return iter, a, 0
        end
    end

    for k,v in pairs({foo = true}) do
        type_assert(k, _ as "foo")
        type_assert(v, _ as true)
    end

    for i,v in ipairs({"LOL",2,3}) do
        type_assert(i, _ as 1)
        type_assert(v, _ as "LOL")
    end
]]
R[[
    type next = function(tbl, _key)
        local key, val

        -- old typesystem
        if tbl.value then

            for k, v in pairs(tbl.value) do
                if not key then
                    key = types.Create(type(k))
                elseif not key:IsType(k) then
                    if type(k) == "string" then
                        key = types.Fuse(key, types.Create("string"))
                    else
                        key = types.Fuse(key, types.Create(k.name))
                    end
                end

                if not val then
                    val = types.Create(type(v))
                else
                    if not val:IsType(v) then
                        val = types.Fuse(val, types.Create(v.name))
                    end
                end
            end
        end

        -- new typesystem
        if tbl.data then
            key, val = types.Set:new(), types.Set:new()
            if tbl.Type == "dictionary" then
                for _, keyval in ipairs(tbl.data) do
                    key:AddElement(keyval.key)
                    val:AddElement(keyval.val)
                end
            elseif tbl.Type == "tuple" then
                key = types.Create("number", i, const)
                key.max = tbl.max and tbl.max:Copy() or nil
                for _, val in ipairs(tbl.data) do
                    val:AddElement(val)
                end
            end
        end

        return key, val
    end

    local a = {
        foo = true,
        bar = false,
        a = 1,
        lol = {},
    }

    local k, v = next(a)
]]
R[[
    local a: _G.string

    type_assert(a, _G.string)
]]
R[[
    local a = ""

    if a is string then
        type_assert(a, _ as "")
    end

]]
R[[
    local a = math.cos(1)
    type_assert(a, nil as number)

    if a is number then
        type_assert(a, _ as number)
    end
]]
R[[
    interface math {
        sin = function(number): number
    }

    interface math {
        cos = function(number): number
    }

    local a = math.sin(1)

    type_assert(a, _ as number)
]]

R[=[
    local a = 1
    function b(lol: number)
        if lol == 1 then return "foo" end
        return lol + 4, true
    end
    local d = b(2)
    local d = b(a)

    local lol: {a = boolean, Foo = function():} = {}
    lol.a = true

    function lol:Foo(foo, bar)
        local a = self.a
    end

    --local lol: string[] = {}

    --local a = table.concat(lol)
]=]

R[[
    type a = function()
        _G.LOL = true
    end

    type b = function()
        _G.LOL = nil
        local t = analyzer:GetValue("a", "typesystem")
        local func = t.data.lua_function
        func()
        if not _G.LOL then
            error("test fail")
        end
    end

    local a = b()
]]
R[[
    a: number = (lol as function(): number)()

    type_assert(a, nil as number)
]]
R[[
    local a = {}
    a.b: boolean, a.c: number = LOL as any, LOL2 as any
]]
R[[
    type test = {
        sin = (function(number): number),
        cos = (function(number): number),
    }

    local a = test.sin(1)
]]
R[[
    type lol = function(a) return a end
    local a: lol<string>
    type_assert(a, _ as string)
]]
R[[
    local a = {}
    function a:lol(a,b,c)
        return a+b+c
    end
    type_assert(a:lol(1,2,3), 6)
]]
R[[
    local a = {}
    function a.lol(_, a,b,c)
        return a+b+c
    end
    type_assert(a:lol(1,2,3), 6)
]]
R[[
    local a = {}
    function a.lol(a,b,c)
        return a+b+c
    end
    type_assert(a.lol(1,2,3), 6)
]]
R[[
    local a = {}
    function a.lol(...)
        local a,b,c = ...
        return a+b+c
    end
    type_assert(a.lol(1,2,3), 6)
]]
R[[
    local a = {}
    function a.lol(foo, ...)
        local a,b,c = ...
        return a+b+c+foo
    end
    type_assert(a.lol(10,1,2,3), 16)
]]
R[[
    local a = (function(...) return ...+... end)(10)
]]
R[[
    local k,v = next({k = 1})
    type_assert(k, nil as "k")
    type_assert(v, nil as 1)
]]
R[[
    -- this will error with not defined
    --type_assert(TOTAL_STRANGER_COUNT, _ as number)
    --type_assert(TOTAL_STRANGER_STRING, _ as string)
]]
R[[
    local a = b as any
    local b = 2
    type_assert(a, _ as any)
]]
R[[
    type test = (function(boolean, boolean): number) | (function(boolean): string)

    local a = test(true, true)
    local b = test(true)

    type_assert(a, _ as [number])
    --type_assert(b, _ as [string]) TODO
]]
R[[
    local type function identity(a)
        return a
    end
]]
R[[
    local a = 1
    while true do
        a = a + 1
    end
    local b = a

    repeat
        b = b + 1
    until true

    local c = b
]]
R[[
    for k,v in next, {1,2,3} do
        print(k,v)
    end
]]
R[[
    local a = {a = self}
]]
R[[
    local a = setmetatable({} as {num = number}, meta)

    type_assert(a.num, _ as number)
]]
R[[
    local meta: {num = number, __index = self} = {}
    meta.__index = meta

    local a = setmetatable({}, meta)

    type_assert(a.num, _ as number) -- implement meta tables
]]
R[[
    local type Vec2 = {x = number, y = number}
    local type Vec3 = {z = number} extends Vec2

    local type Base = {
        Test = function(self): number,
    }

    local type Foo = Base extends {
        SetPos = (function(self, pos: Vec3): nil),
        GetPos = (function(self): Vec3),
    }

    local x: Foo = {}
    x:SetPos({x = 1, y = 2, z = 3})
    local a = x:GetPos()
    local z = a.x + 1

    type_assert(z, _ as number)

    local test = x:Test()
    type_assert(test, _ as number)
]]
R[[
    local function lol()
        return "hello", 1337
    end

    local a = lol():gsub("", "")

    type_assert(a, _ as string)
]]
R[[

    local a,b,c = string.match("1 2 3", "(%d) (%d) (%d)")
    type_assert(a, nil as "1")
    type_assert(b, nil as "2")
    type_assert(c, nil as "3")

]]
R[[
    -- val should be a string and lol should be any
    string.gsub("foo bar", "(%s)", function(val, lol)
        type_assert(val, _ as string)
        type_assert(lol, _ as any)
    end)
]]
R[[
    local _: boolean
    local a = 0

    -- boolean which has no known value should be truthy
    if _ then
        a = 1
    end
    type_assert(a, 1)
]]
R[[
    -- 1..any
    for i = 1, _ do

    end
]]
R[[
    local a, b = 0, 0
    for i = 1, 10 do
        if 5 == i then
            a = 1
        end
        if i == 5 then
            b = 1
        end
    end
    type_assert(a, 1)
    type_assert(b, 1)
]]
R[[
    local def,{a,b,c} = {a=1,b=2,c=3}
    type_assert(a, 1)
    type_assert(b, 2)
    type_assert(c, 3)
    type_assert(def, def)
]]
R[[
    -- local a = nil
    -- local b = a and a.b or 1
 ]]
R[[
    local tbl = {} as {[true] = false}
    tbl[true] = false
    type_assert(tbl[true], false)
 ]]
R[[
    local tbl = {} as {1,true,3}
    tbl[1] = 1
    tbl[2] = true
 ]]

R[[
    local tbl: {1,true,3} = {1, true, 3}
    tbl[1] = 1
    tbl[2] = true
    tbl[3] = 3
 ]]

R[[
    local tbl: {1,true,3} = {1, true, 3}
    tbl[1] = 1
    tbl[2] = true
    tbl[3] = 3
 ]]
R[[
    local pl = {IsValid = function(self) end}
    local a = pl:IsValid()
    type_assert(a, nil)
 ]]
R[[
    --local a: {[number] = any} = {}
    local a = {}
    a[1] = true
    a[2] = false
    table.insert(a, 1337)
    type_assert(a[3], 1337)
 ]]
R[[
    type test = function(name)
         return analyzer:GetValue(name.data, "typesystem")
    end
    local type lol = {}
    type_assert(test("lol"), lol)
]]
R[[
    local type lol = {}
    type_assert(require("lol"), lol)
]]
R[[
    local tbl = {}
    local test = "asdawd"
  --  tbl[test] = tbl[test] or {} TODO
    tbl[test] = "1"
    type_assert(tbl[test], nil as "1")
]]
R[[
    local function fill(t)
        for i = 1, 10 do
            t[i] = i
        end
    end
    local tbl = {}
    fill(tbl)
]]
R[[
    tbl, {a,b} = {a=1,b=2}

    type_assert(tbl.a, nil as 1)
    type_assert(tbl.b, nil as 2)
    type_assert(a, nil as 1)
    type_assert(b, nil as 2)
]]
R[[
    local type a = 1
    type_assert(a, 1)
]]
R[[
    local a = function(): number,string return 1,"" end
]]
R[[
    assert(1 == 1, "lol")
]]
R[[
    local function test(a, b)

    end

    test(true, false)
    test(false, true)
    test(1, "")

    local type check = function(func)
        local a = func.data.arg.data[1]
        local b = types.Set:new({
            types.Object:new("number", 1, true),
            types.Object:new("boolean", false, true),
            types.Object:new("boolean", true, true)
        })

        assert(b:SupersetOf(a))
    end

    check(test, "!")
]]

R[[
    type_assert_superset(math.floor(1), 1)
]]

R([[require("adawdawddwaldwadwadawol")]], "unable to find module")

R([[local a = 1 a()]], "number.-cannot be called")

R([[
    local a: {[string] = any} = {} -- can assign a string to anything, (most common usage)
    a.lol = "aaa"
    a.lol2 = 2
    a.lol3 = {}
    a[1] = {}
 ]], "invalid key number")
R([[
        local {a,b} = nil
    ]], "expected a table on the right hand side, got")
R([[
        local a: {[string] = string} = {}
        a.lol = "a"
        a[1] = "a"
    ]], "invalid key number.-expected string")
R([[
        local a: {[string] = string} = {}
        a.lol = 1
    ]], "invalid value number.-expected string")
R([[
        local a: {} = {}
        a.lol = true
     ]], "invalid key string")
R([[
        local tbl: {1,true,3} = {1, true, 3}
        tbl[2] = false
     ]], "invalid value boolean.-expected.-true")
R([[
        local tbl: {1,true,3} = {1, false, 3}
    ]], "expected .- but the right hand side is ")
R([[
        assert(1 == 2, "lol")
    ]],"lol")

R([[
    local a: {} = {}
    a.lol = true
]],"invalid key")

R([[
    local a = 1
    a.lol = true
]],"undefined set:")

R([[local a = 1; a = a.lol]],"undefined get:")
R([[local a = 1 + true]], "no operator for.-number.-%+.-boolean")

R([[
    --: local type a = 1
    type_assert(a, 1)
]])

R([[
    type a = {}

    if not a then
        -- shouldn't reach
        type_assert(1, 2)
    else
        type_assert(1, 1)
    end
]])

R([[
    type a = {}
    if not a then
        -- shouldn't reach
        type_assert(1, 2)
    end
]])

