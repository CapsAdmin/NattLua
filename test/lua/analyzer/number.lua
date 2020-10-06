local T = require("test.helpers")
local run = T.RunCode

test("number range", function()
    assert(run("local a: 1 .. 10 = 5"):GetEnvironmentValue("a", "runtime").contract.max)
    run("local a: 1 .. 10 = 15", "15 is not a subset of 1..10")
end)

test("number range 0 .. inf", function()
    assert(run("local a: 1 .. inf = 5"):GetEnvironmentValue("a", "runtime").contract.max)
    run("local a: 1 .. inf = -15", "-15 is not a subset of 1..inf")
end)

test("number range -inf .. 0", function()
    assert(run("local a: -inf .. 0 = -5"):GetEnvironmentValue("a", "runtime").contract.max)
    run("local a: -inf .. 0 = 15", "15 is not a subset of %-inf..0")
end)

test("number range -inf .. inf", function()
    assert(run("local a: -inf .. inf = -5"):GetEnvironmentValue("a", "runtime").contract.max)
    run("local a: -inf .. inf = 0/0", "nan is not a subset of %-inf..inf")
end)

test("number range -inf .. inf | nan", function()
    assert(run("local a: -inf .. inf | nan = 0/0"):GetEnvironmentValue("a", "runtime").contract.Type == "set")
end)

test("cannot not be called", function()
    run([[local a = 1 a()]], "1 cannot be called")
end)

test("cannot be indexed", function()
    run([[local a = 1; a = a.lol]],"undefined get:")
end)

test("cannot be added to another type", function()
    run([[local a = 1 + true]], "no operator for 1 %+ .-true in runtime")
end)

test("literal number + number = number", function()
    local a = run([[
        local a = 1 + (_ as number)

        type_assert(a, _ as number)
    ]])
end)

test("nan", function()
    run([[
        local function isNaN (x)
            return (x ~= x)
        end

        assert(isNaN(0/0))
        assert(not isNaN(1/0))
    ]])
end)

test("integer division", function()
    run[[
        local foo = ((500 // 2) + 3) // 2 // 3 // 3
        local bar = 5
        type_assert(foo, 14)
        type_assert(bar, 5)
    ]]
end)