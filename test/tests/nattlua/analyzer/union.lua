local LString = require("nattlua.types.string").LString

do -- smoke
	local a = analyze[[local type a = 1337 | 8888]]
	a:PushAnalyzerEnvironment("typesystem")
	local union = a:GetLocalOrGlobalValue(LString("a"))
	a:PopAnalyzerEnvironment()
	equal(2, union:GetCardinality())
	equal(1337, union:GetData()[1]:GetData())
	equal(8888, union:GetData()[2]:GetData())
end

do -- leading pipe smoke
	local a = analyze[[local type a = | 1337 | 8888]]
	a:PushAnalyzerEnvironment("typesystem")
	local union = a:GetLocalOrGlobalValue(LString("a"))
	a:PopAnalyzerEnvironment()
	equal(2, union:GetCardinality())
	equal(1337, union:GetData()[1]:GetData())
	equal(8888, union:GetData()[2]:GetData())
end

do -- empty union smoke
	local a = analyze[[local type a = |]]
	a:PushAnalyzerEnvironment("typesystem")
	local union = a:GetLocalOrGlobalValue(LString("a"))
	a:PopAnalyzerEnvironment()
	equal(union.Type, "union")
	equal(0, union:GetCardinality())
end

do -- union operator
	local a = analyze[[
        local type a = 1337 | 888
        local type b = 666 | 777
        local type c = a | b
    ]]
	a:PushAnalyzerEnvironment("typesystem")
	local union = a:GetLocalOrGlobalValue(LString("c"))
	a:PopAnalyzerEnvironment()
	equal(4, union:GetCardinality())
end

analyze[[
        --union + object
        local a = _ as (1 | 2) + 3
        attest.equal(a, _ as 4 | 5)
    ]]
analyze[[
        --union + union
        local a = _ as 1 | 2
        local b = _ as 10 | 20

        attest.equal(a + b, _ as 11 | 12 | 21 | 22)
    ]]
analyze[[
        --union.foo
        local a = _ as {foo = true} | {foo = false}

        attest.equal(a.foo, _ as true | false)
    ]]
analyze[[
        --union.foo = bar
        local type a = { foo = 4 } | { foo = 1|2 } | { foo = 3 }
        attest.equal<|a.foo, 1 | 2 | 3 | 4|>
    ]]

do --is literal
	local a = analyze[[
        local type a = 1 | 2 | 3
    ]]
	a:PushAnalyzerEnvironment("typesystem")
	assert(a:GetLocalOrGlobalValue(LString("a")):IsLiteral() == true)
	a:PopAnalyzerEnvironment()
end

do -- is not literal
	local a = analyze[[
        local type a = 1 | 2 | 3 | string
    ]]
	a:PushAnalyzerEnvironment("typesystem")
	assert(a:GetLocalOrGlobalValue(LString("a")):IsLiteral() == false)
	a:PopAnalyzerEnvironment()
end

analyze[[
    local x: any | function=()>(boolean)
    x()
]]
analyze[[
    local function test(x: {}  | {foo = nil | 1})
        attest.equal(x.foo, _ as nil | 1)
        if x.foo then
            attest.equal(x.foo, 1)
        end
    end

    test({})
]]
analyze[[
    local type a = 1 | 5 | 2 | 3 | 4
    local type b = 5 | 3 | 4 | 2 | 1
    attest.equal<|a == b, true|>
]]
analyze[[
    local shapes = _ as {[number] = 1} | {[number] = 2} | {[number] = 3}
    attest.equal(shapes[0], _ as 1|2|3|nil)
]]
analyze(
	[[
    local shapes = _ as {[number] = 1} | {[number] = 2} | {[number] = 3}| false
    local x = shapes[0]
]],
	"false.-0.-on type symbol"
)
analyze([[
    local a: nil | {}
    a.foo = true
]], "undefined set.- = true")
analyze(
	[[
    local b: nil | {foo = true}
    local c = b.foo
]],
	"undefined get: nil.-foo"
)
analyze([[
    local analyzer function test(a: any, b: any)
        local arg = types.Tuple()
        local ret = types.Tuple()
    
        for _, func in ipairs(a:GetData()) do
            if func.Type ~= "function" then return false end
    
            arg:Merge(func:GetInputSignature())
            ret:Merge(func:GetOutputSignature())
        end
    
        local f = types.Function(arg, ret)

        assert(f:Equal(b))
    end
    local type A = function=(string)>(number)
    local type B = function=(number)>(boolean)
    local type C = function=(number | string)>(boolean | number)
    
    test<|A|B, C|>
]])
analyze[[
    local type a = |
    type a = a | 1
    type a = a | 2
    attest.equal<|a, 1|2|>
]]
analyze[[
    local type tbl = {[number] = string} | {}
    attest.equal<|tbl[1], string|>
]]
analyze[[
    local function test(foo: string)
    end
    
    local type t = | 
    
    attest.expect_diagnostic("error", "nil is not a subset of string")
    test(t)
]]
analyze[[
    local type s = _  as string | string
    string.reverse(s)
]]
analyze[[
table.remove(_ as {[number] = number}, _ as (-inf .. 2) | 1)
]]
analyze[[
table.remove(_ as {[number] = number}, _ as (-inf .. 2) | 1)
]]
analyze[[
local analyzer function test(x: number, b: boolean, x2: number)
    
	return x:IsLiteral() and math.abs(x:GetData()) or types.Number(), not b, x2:IsLiteral() and math.abs(x2:GetData()) or types.Number()
end

local x = _ as 1337 | 666 | (-10 .. -5)
local a, b, c = test(x, true, _ as x)
attest.equal(a, _ as 10 | 1337 | 5 | 666 | number)
attest.equal(b, false)
attest.equal(c, a)
]]
analyze[[
local pos = _ as number
local b0, b1, b2, b3 = string.byte(_ as string, pos + 1, pos + 4)
local op = bit.bor(bit.lshift(b3, 24), bit.lshift(b2, 16), bit.lshift(b1, 8), b0)
local cond = bit.rshift(op, 28)
attest.equal(cond <= 15, _ as boolean)
]]
