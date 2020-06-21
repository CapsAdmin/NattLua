local T = require("spec.lua.helpers")
local run = T.RunCode
do return end
describe("callstack", function()
    it("lol", function()
        run[[

            local function foo()
                error("LOL")
            end

            local function bar()
                if true then
                    foo()
                end
            end

            local lol = function()
                bar()
            end

            lol()
        ]]
    end)
end)