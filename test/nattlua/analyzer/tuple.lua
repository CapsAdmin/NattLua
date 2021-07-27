local T = require("test.helpers")
local run = T.RunCode

run[[
    local type A = Tuple<|1,2|>
    local type B = Tuple<|3,4|>
    local type C = A .. B
    types.assert<|C, Tuple<|1,2,3,4|>|>
]]

-- test for most edge cases regarding the tuple unpack mess
run[[

local function test() return function(num: literal number) return 1336 + num end end

types.assert(test()(1), 1337)
local a = test()(1)
types.assert(a, 1337)

for i = 1, test()(1) - 1336 do
    types.assert(i, 1)
end

local a,b,c = (function() return 1,2,3 end)()

types.assert(a, 1)
types.assert(b, 2)
types.assert(c, 3)

local x = (function() if math.random() > 0.5 then return 1 end return 2 end)()

types.assert(x, _ as 1 | 2)

local function lol()
    if math.random() > 0.5 then
        return 1
    end
end

local x = lol()

types.assert<|x, 1 | nil|>

local function func(): number, number
    if math.random() > 0.5 then
        return 1, 2
    end

    return 3, 2
end


local foo: function(): Tuple<|true, 1|> | Tuple<|false, string, 2|>
local x,y,z = foo() 
types.assert(x, _ as boolean)
types.assert(y, _ as 1 | string)
types.assert(z, _ as 2 | nil)


local function foo()
    return 2,true, 1
end

foo()

types.assert<|ReturnType<|foo|>, Tuple<|2,true,1|>|>

local function test()
    if math.random() > 0.5 then
        return 1, 2
    end
    return 1, (function() return 2 end)()
end

test()

types.assert<|ReturnType<|test|>, Tuple<|1, 2|>|>


local a = function()
    if math.random() > 0.5 then
        -- the return value here sneaks into val
        return ""
    end
    
    -- val is "" | 1
    local val = (function() return 1 end)()
    
    types.assert(val, 1)

    return val
end

types.assert(a(), _ as 1 | "")

local type function Union(...)
    return types.Union({...})
end

local function Extract<|a: any, b: any|>
	local out = Union<||>
    for aval in UnionPairs(a) do
		for bval in UnionPairs(b) do
			if aval < bval then
				out = out | aval
			end
		end
	end

	return out
end

types.assert<|Extract<|1337 | 231 | "deadbeef", number|>, 1337 | 231|>

local type function foo() 
    return 1
end

local a = {
    foo = foo()
}

§assert(analyzer:GetScope():FindValue(types.LString("a"), "runtime"):GetValue():Get(types.LString("foo")).Type ~= "tuple")


local function prefix (w1: literal string, w2: literal string)
    return w1 .. ' ' .. w2
end

local w1,w2 = "foo", "bar"
local statetab = {["foo bar"] = 1337}

local test = statetab[prefix(w1, w2)]
types.assert(test, 1337)


types.assert({(_ as any)()}, _ as {[1 .. inf] = any})
types.assert({(_ as any)(), 1}, _ as {any, 1})

local tbl = {...}
types.assert(tbl[1], _ as any)
types.assert(tbl[2], _ as any)
types.assert(tbl[100], _ as any)

;(function(...)   
    local tbl = {...}
    types.assert(tbl[1], 1)
    types.assert(tbl[2], 2)
    types.assert(tbl[100], _ as nil) -- or nil?
end)(1,2)

]]

run([[
    local function func(): number, number
        return 1
    end
]], "index 2 does not exist")