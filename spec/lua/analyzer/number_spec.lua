local T = require("spec.lua.helpers")
local run = T.RunCode

describe("number", function()
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

    it("cannot not be called", function()
        run([[local a = 1 a()]], "1 cannot be called")
    end)

    it("cannot be indexed", function()
        run([[local a = 1; a = a.lol]],"undefined get:")
    end)

    it("cannot be added to another type", function()
        run([[local a = 1 + true]], "no operator for 1 %+ .-true in runtime")
    end)

    it("literal number + number = number", function()
        local a = run([[
            local a = 1 + (_ as number)

            type_assert(a, _ as number)
        ]])
    end)

    it("nan", function()
        run([[
            local function isNaN (x)
                return (x ~= x)
            end

            assert(isNaN(0/0))
            assert(not isNaN(1/0))
        ]])
    end)
end)