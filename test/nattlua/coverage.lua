do return end
local coverage = require("nattlua.other.coverage")

local function collect(code)
    assert(loadstring(coverage.Preprocess(code, "test")))()
    return coverage.Collect("test")
end

collect([[

    local foo = {
        bar = function() 
            local x = 1
        end
    }

    foo:bar()

    for i = 1, 10 do
        if i == 15 then
            notCovered:Test()
        end
    end
]])

