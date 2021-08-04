local T = require("test.helpers")
local run = T.RunCode
local String = T.String
test("smoke", function()
    local a = run[[local type a = 1337 | 8888]]:GetLocalOrEnvironmentValue(String("a"), "typesystem")
    equal(2, a:GetLength())
    equal(1337, a:GetData()[1]:GetData())
    equal(8888, a:GetData()[2]:GetData())
end)

test("union operator", function()
    local a = run[[
        local type a = 1337 | 888
        local type b = 666 | 777
        local type c = a | b
    ]]:GetLocalOrEnvironmentValue(String("c"), "typesystem")
    equal(4, a:GetLength())
end)

test("union + object", function()
    run[[
        local a = _ as (1 | 2) + 3
        types.assert(a, _ as 4 | 5)
    ]]
end)

test("union + union", function()
    run[[
        local a = _ as 1 | 2
        local b = _ as 10 | 20

        types.assert(a + b, _ as 11 | 12 | 21 | 22)
    ]]
end)

test("union.foo", function()
    run[[
        local a = _ as {foo = true} | {foo = false}

        types.assert(a.foo, _ as true | false)
    ]]
end)

test("union.foo = bar", function()
    run[[
        local type a = { foo = 4 } | { foo = 1|2 } | { foo = 3 }
        types.assert<|a.foo, 1 | 2 | 3 | 4|>
    ]]
end)

test("is literal", function()
    local a = run[[
        local type a = 1 | 2 | 3
    ]]
    assert(a:GetLocalOrEnvironmentValue(String("a"), "typesystem"):IsLiteral() == true)
end)

test("is not literal", function()
    local a = run[[
        local type a = 1 | 2 | 3 | string
    ]]
    assert(a:GetLocalOrEnvironmentValue(String("a"), "typesystem"):IsLiteral() == false)
end)

run[[
    local x: any | function(): boolean
    x()
]]


pending[[
    local function test(x: {}  | {foo = nil | 1})
        print(x.foo)
        if x.foo then
            print(x.foo)
        end
    end

    test({})
]]

run[[
    local type a = 1 | 5 | 2 | 3 | 4
    local type b = 5 | 3 | 4 | 2 | 1
    types.assert<|a == b, true|>
]]

run[[
    local shapes = _ as {[number] = 1} | {[number] = 2} | {[number] = 3}
    types.assert(shapes[0], _ as 1|2|3)
]]

run([[
    local shapes = _ as {[number] = 1} | {[number] = 2} | {[number] = 3}| false
    local x = shapes[0]
]], "false.-0.-on type symbol")

run([[
    local a: nil | {}
    a.foo = true
]], "undefined set.- = true")

run([[
    local b: nil | {foo = true}
    local c = b.foo
]], "undefined get: nil.-foo")

run([[
    local type function test(a, b)
        assert(a:ShrinkToFunctionSignature():Equal(b))
    end
    local type A = function(string): number
    local type B = function(number): boolean
    local type C = function(number | string): boolean | number
    
    test<|A|B, C|>
]])

run[[
    local type a = |
    type a = a | 1
    type a = a | 2
    types.assert<|a, 1|2|>
]]