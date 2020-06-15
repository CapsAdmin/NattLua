local T = require("spec.lua.helpers")
local run = T.RunCode

it("number range", function()
    assert(run("local a: 1 .. 10 = 5"):GetValue("a", "runtime").contract.max)
    run("local a: 1 .. 10 = 15", "15 is not a subset of 1..10")
end)

it("number range 0 .. inf", function()
    assert(run("local a: 1 .. inf = 5"):GetValue("a", "runtime").contract.max)
    run("local a: 1 .. inf = -15", "-15 is not a subset of 1..inf")
end)

it("number range -inf .. 0", function()
    assert(run("local a: -inf .. 0 = -5"):GetValue("a", "runtime").contract.max)
    run("local a: -inf .. 0 = 15", "15 is not a subset of %-inf..0")
end)


it("number range -inf .. inf", function()
    assert(run("local a: -inf .. inf = -5"):GetValue("a", "runtime").contract.max)
    run("local a: -inf .. inf = 0/0", "nan is not a subset of %-inf..inf")
end)

it("number range -inf .. inf | nan", function()
    assert(run("local a: -inf .. inf | nan = 0/0"):GetValue("a", "runtime").contract.Type == "set")
end)