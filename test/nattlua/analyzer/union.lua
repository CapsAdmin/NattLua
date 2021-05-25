local T = require("test.helpers")
local run = T.RunCode

test("smoke", function()
    local a = run[[local type a = 1337 | 8888]]:GetLocalOrEnvironmentValue(types.LString("a"), "typesystem")
    equal(2, a:GetLength())
    equal(1337, a:GetData()[1]:GetData())
    equal(8888, a:GetData()[2]:GetData())
end)

test("union operator", function()
    local a = run[[
        local type a = 1337 | 888
        local type b = 666 | 777
        local type c = a | b
    ]]:GetLocalOrEnvironmentValue(types.LString("c"), "typesystem")
    equal(4, a:GetLength())
end)

test("union + object", function()
    run[[
        local a = _ as (1 | 2) + 3
        type_assert(a, _ as 4 | 5)
    ]]
end)

test("union + union", function()
    run[[
        local a = _ as 1 | 2
        local b = _ as 10 | 20

        type_assert(a + b, _ as 11 | 12 | 21 | 22)
    ]]
end)

test("union.foo", function()
    run[[
        local a = _ as {foo = true} | {foo = false}

        type_assert(a.foo, _ as true | false)
    ]]
end)

test("union.foo = bar", function()
    run[[
        local type a = { foo = 4 } | { foo = 1|2 } | { foo = 3 }
        type_assert<|a.foo, 1 | 2 | 3 | 4|>
    ]]
end)

test("is literal", function()
    local a = run[[
        local type a = 1 | 2 | 3
    ]]
    assert(a:GetLocalOrEnvironmentValue(types.LString("a"), "typesystem"):IsLiteral() == false)
end)

test("is not literal", function()
    local a = run[[
        local type a = 1 | 2 | 3 | string
    ]]
    assert(a:GetLocalOrEnvironmentValue(types.LString("a"), "typesystem"):IsLiteral() == false)
end)

run[[
    local x: any | function(): boolean
    x()
]]

run([[
    local a: nil | {}
    a.foo = true
    type_assert(a, {foo = true})
]], "undefined set.- = true")

run([[
    local b: nil | {foo = true}
    local c = b.foo
    type_assert(c, true)
]], "undefined get: nil.-foo")

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
    type_assert<|a == b, true|>
]]