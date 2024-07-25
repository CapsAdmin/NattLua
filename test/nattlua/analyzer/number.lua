local T = require("test.helpers")
local analyze = T.RunCode
local String = T.String

do -- number range
	assert(
		analyze("local a: 1 .. 10 = 5"):GetLocalOrGlobalValue(String("a")):GetContract():GetMax()
	)
	analyze("local a: 1 .. 10 = 15", "15 is not a subset of 1..10")
end

do -- number range 0 .. inf
	assert(
		analyze("local a: 1 .. inf = 5"):GetLocalOrGlobalValue(String("a")):GetContract():GetMax()
	)
	analyze("local a: 1 .. inf = -15", "-15 is not a subset of 1..inf")
end

do -- number range -inf .. 0
	assert(
		analyze("local a: -inf .. 0 = -5"):GetLocalOrGlobalValue(String("a")):GetContract():GetMax()
	)
	analyze("local a: -inf .. 0 = 15", "15 is not a subset of %-inf..0")
end

do -- number range -inf .. inf
	assert(
		analyze("local a: -inf .. inf = -5"):GetLocalOrGlobalValue(String("a")):GetContract():GetMax()
	)
	analyze("local a: -inf .. inf = 0/0", "nan is not a subset of %-inf..inf")
end

do -- number range -inf .. inf | nan
	assert(analyze("local a: -inf .. inf | nan = 0/0"):GetLocalOrGlobalValue(String("a")):GetContract().Type == "union")
end

do -- cannot not be called
	analyze([[local a = 1 a()]], "1 cannot be called")
end

do -- cannot be indexed
	analyze([[local a = 1; a = a.lol]], "undefined get:")
end

do -- cannot be added to another type
	analyze([[local a = 1 + true]], "1 %+ .-true is not a valid binary operation")
end

analyze([[
        local a = 1 + (_ as number)

        attest.equal(a, _ as number)
    ]])
analyze([[
        local function isNaN (x)
            return (x ~= x)
        end

        assert(isNaN(0/0))
        assert(not isNaN(1/0))
    ]])
analyze[[
        local foo = ((500 // 2) + 3) // 2 // 3 // 3
        local bar = 5
        attest.equal(foo, 14)
        attest.equal(bar, 5)
    ]]
analyze[[
    local n = _ as 0 .. 1

    attest.equal(n > 1, false)
    attest.equal(n > 0.5, _ as boolean)
    attest.equal(n >= 1, _ as boolean)
    attest.equal(n <= 0, _ as boolean)
    attest.equal(n < 0, false)
    
    local n2 = _ as 0.5 .. 1.5
    
    attest.equal(n2 + n, _ as 0.5 .. 2.5)
]]
analyze[[
    local x: 1..inf = 2
    attest.equal<|x, 1..inf|>
]]