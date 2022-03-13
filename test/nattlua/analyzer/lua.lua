local ipairs = ipairs
local pairs = pairs
local tostring = _G.tostring
local T = require("test.helpers")
local run = T.RunCode
local bit = _G.bit32 or _G.bit

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

            attest.equal(x<y,	true)
            attest.equal(x<=y,	true)
            attest.equal(x>y,	false)
            attest.equal(x>=y,	false)
            attest.equal(x==y,	false)
            attest.equal(x~=y,	true)

            attest.equal(1<y,	true)
            attest.equal(1<=y,	true)
            attest.equal(1>y,	false)
            attest.equal(1>=y,	false)
            attest.equal(1==y,	false)
            attest.equal(1~=y,	true)

            attest.equal(x<2,	true)
            attest.equal(x<=2,	true)
            attest.equal(x>2,	false)
            attest.equal(x>=2,	false)
            attest.equal(x==2,	false)
            attest.equal(x~=2,	true)

            attest.equal(lt(x,y),	true)
            attest.equal(le(x,y),	true)
            attest.equal(gt(x,y),	false)
            attest.equal(ge(x,y),	false)
            attest.equal(eq(y,x),	false)
            attest.equal(ne(y,x),	true)
        end

        do --- 2,1
            local x,y = 2,1

            attest.equal(x<y,	false)
            attest.equal(x<=y,	false)
            attest.equal(x>y,	true)
            attest.equal(x>=y,	true)
            attest.equal(x==y,	false)
            attest.equal(x~=y,	true)

            attest.equal(2<y,	false)
            attest.equal(2<=y,	false)
            attest.equal(2>y,	true)
            attest.equal(2>=y,	true)
            attest.equal(2==y,	false)
            attest.equal(2~=y,	true)

            attest.equal(x<1,	false)
            attest.equal(x<=1,	false)
            attest.equal(x>1,	true)
            attest.equal(x>=1,	true)
            attest.equal(x==1,	false)
            attest.equal(x~=1,	true)

            attest.equal(lt(x,y),	false)
            attest.equal(le(x,y),	false)
            attest.equal(gt(x,y),	true)
            attest.equal(ge(x,y),	true)
            attest.equal(eq(y,x),	false)
            attest.equal(ne(y,x),	true)
        end

        do --- 1,1
            local x,y = 1,1

            attest.equal(x<y,	false)
            attest.equal(x<=y,	true)
            attest.equal(x>y,	false)
            attest.equal(x>=y,	true)
            attest.equal(x==y,	true)
            attest.equal(x~=y,	false)

            attest.equal(1<y,	false)
            attest.equal(1<=y,	true)
            attest.equal(1>y,	false)
            attest.equal(1>=y,	true)
            attest.equal(1==y,	true)
            attest.equal(1~=y,	false)

            attest.equal(x<1,	false)
            attest.equal(x<=1,	true)
            attest.equal(x>1,	false)
            attest.equal(x>=1,	true)
            attest.equal(x==1,	true)
            attest.equal(x~=1,	false)

            attest.equal(lt(x,y),	false)
            attest.equal(le(x,y),	true)
            attest.equal(gt(x,y),	false)
            attest.equal(ge(x,y),	true)
            attest.equal(eq(y,x),	true)
            attest.equal(ne(y,x),	false)
        end

        do --- 2
            attest.equal(lt1x(2),	true)
            attest.equal(le1x(2),	true)
            attest.equal(gt1x(2),	false)
            attest.equal(ge1x(2),	false)
            attest.equal(eq1x(2),	false)
            attest.equal(ne1x(2),	true)

            attest.equal(ltx1(2),	false)
            attest.equal(lex1(2),	false)
            attest.equal(gtx1(2),	true)
            attest.equal(gex1(2),	true)
            attest.equal(eqx1(2),	false)
            attest.equal(nex1(2),	true)
        end

        do --- 1
            attest.equal(lt1x(1),	false)
            attest.equal(le1x(1),	true)
            attest.equal(gt1x(1),	false)
            attest.equal(ge1x(1),	true)
            attest.equal(eq1x(1),	true)
            attest.equal(ne1x(1),	false)

            attest.equal(ltx1(1),	false)
            attest.equal(lex1(1),	true)
            attest.equal(gtx1(1),	false)
            attest.equal(gex1(1),	true)
            attest.equal(eqx1(1),	true)
            attest.equal(nex1(1),	false)
        end

        do --- 0
            attest.equal(lt1x(0),	false)
            attest.equal(le1x(0),	false)
            attest.equal(gt1x(0),	true)
            attest.equal(ge1x(0),	true)
            attest.equal(eq1x(0),	false)
            attest.equal(ne1x(0),	true)

            attest.equal(ltx1(0),	true)
            attest.equal(lex1(0),	true)
            attest.equal(gtx1(0),	false)
            attest.equal(gex1(0),	false)
            attest.equal(eqx1(0),	false)
            attest.equal(nex1(0),	true)
        end
    ]]
end)

test("boolean and or logic", function() -- and or
	-- when false, or returns its second argument
	run("attest.equal(nil or false, false)")
	run("attest.equal(false or nil, nil)")
	-- when true, or returns its first argument
	run("attest.equal(1 or false, 1)")
	run("attest.equal(true or nil, true)")
	run("attest.equal(nil or {}, {})")
	-- boolean without any data can be true and false at the same time
	run("attest.equal((_ as boolean) or (1), _ as true | 1)")
	-- when false and returns its first argument
	run("attest.equal(false and true, false)")
	run("attest.equal(true and nil, nil)")
	-- when true and returns its second argument
	-- ????
	-- smoke test
	run("attest.equal(((1 or false) and true) or false, true)")

	do --- allcases
		local basiccases = {
			{"nil", nil},
			{"false", false},
			{"true", true},
			{"10", 10},
		}
		local mem = {basiccases} -- for memoization
		local function allcases(n)
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
							v1[2] and
							v2[2],
						}
						res[#res + 1] = {
							"(" .. v1[1] .. " or " .. v2[1] .. ")",
							v1[2] or
							v2[2],
						}
					end
				end
			end

			mem[n] = res -- memoize
			return res
		end

		for _, v in pairs(allcases(4)) do
			run("attest.equal(" .. tostring(v[1]) .. ", " .. tostring(v[2]) .. ")")
		end
	end
end)

if bit.tobit then
	test("bit operations", function()
		run[[
            for i=1,100 do
                type_assert_truthy(bit.tobit(i+0x7fffffff) < 0)
            end
            for i=1,100 do
                type_assert_truthy(bit.tobit(i+0x7fffffff) <= 0)
            end
        ]]
	end)
end

test("string comparisons", function()
	run[[
        do
            local a = "\255\255\255\255"
            local b = "\1\1\1\1"

            type_assert_truthy(a > b)
            type_assert_truthy(a > b)
            type_assert_truthy(a >= b)
            type_assert_truthy(b <= a)
        end

        do --- String comparisons:
            local function str_cmp(a, b, lt, gt, le, ge)
                type_assert_truthy(a<b == lt)
                type_assert_truthy(a>b == gt)
                type_assert_truthy(a<=b == le)
                type_assert_truthy(a>=b == ge)
                type_assert_truthy((not (a<b)) == (not lt))
                type_assert_truthy((not (a>b)) == (not gt))
                type_assert_truthy((not (a<=b)) == (not le))
                type_assert_truthy((not (a>=b)) == (not ge))
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
            attest.equal(a==b, true)
            attest.equal(a~=b, false)
        end

        local function obj_ne(a, b)
            attest.equal(a==b, false)
            attest.equal(a~=b, true)
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
        attest.equal(t==t2, _ as false)
        attest.equal(t~=t2, _ as true)
        obj_ne(t, 1)
        obj_ne(t, "")
    ]]
end)
