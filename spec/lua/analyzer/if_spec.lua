local T = require("spec.lua.helpers")
local run = T.RunCode

describe("if statements", function()
    it("control path within a function should work", function()
        run([[
            local a = 1
            function b(lol)
                if lol == 1 then return "foo" end
                return lol + 4, true
            end
            local d = b(2)
            type_assert(d, 6)
            local d = b(a)
            type_assert(d, "foo")
        ]])
    end)

    it("lol", function()
        run[[
            local function test(i)
                if i == 20 then
                    return false
                end

                if i == 5 then
                    return true
                end

                return "lol"
            end

            local a = test(20) -- false
            local b = test(5) -- true
            local c = test(1) -- "lol"

            type_assert(a, false)
            type_assert(b, true)
            type_assert(c, "lol")
        ]]
    end)

    it("lol", function()
        run[[
            local function test(max)
                for i = 1, max do
                    if i == 20 then
                        return false
                    end

                    if i == 5 then
                        return true
                    end
                end
            end

            local a = test(20)
            type_assert(a, _ as true | false)
        ]]
    end)
end)