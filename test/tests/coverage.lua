local coverage = require("test.helpers.coverage")

local function collect(code)
	assert(loadstring(coverage.Preprocess(code, "test")))()
    local res = coverage.Collect("test")
    coverage.Clear("test")
    return res
end

collect([[

    local foo = {
        bar = function() 
            local x = 1
            x = x + 1
            do return x end
            return x
        end
    }

    --foo:bar()

    for i = 1, 10 do
        -- lol
        if i == 15 then
            while false do
                notCovered:Test()
            end
        end
    end
]])
collect([=[
    local analyze = function() end
    analyze([[]])
    analyze[[]]  
]=])
collect[[
    local tbl = {}
    function tbl.ReceiveJSON(data, methods, ...)

    end
]]
assert(collect[[
local x = 1
local y = 2
local z = x + y or true]]==[=[local x = --[[1]]1
local y = --[[1]]2
local z = --[[1]]--[[1]]--[[1]]x + --[[1]]y or true]=])