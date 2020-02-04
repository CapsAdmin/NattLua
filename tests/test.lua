
local current_category

function describe(category)
    current_category = {
        name = category, 
        parent = current_category,
    }
end

function it(description)
    return setmetatable({}, {__call = function(_, callback)
        local t = os.clock()
        local ok, err = pcall(callback)
        local diff = os.clock() - t

        if ok then
            io.write("OK - " .. current_category.name .. " " .. description, " ", math.ceil(diff * 1000), "ms", "\n")
        else
            io.write("FAIL - " .. current_category.name .. " " .. description .. ": " .. err:match("^.-: (.+)"), "\n")
        end
    end})
end

local assert = {}

function assert.equal(a, b)
    if a ~= b then
        error(tostring(a) .. " does not equal " .. tostring(b), 2)
    end
end

describe "test"
    it "should fail" (function()
        assert.equal(1, 2)
    end)

    it "should work" (function()
        assert.equal(1, 1)
    end)
    