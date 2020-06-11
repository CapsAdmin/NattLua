local oh = require("oh")
local C = oh.Code

local function run(code, expect_error)
    local code_data = oh.Code(code, nil, nil, 3)
    local ok, err = code_data:Analyze()

    if expect_error then
        if not err then
            error("expected error, got\n\n\n[" .. tostring(ok) .. ", " .. tostring(err) .. "]")
        elseif type(expect_error) == "string" and not err:find(expect_error) then
            error("expected error " .. expect_error .. " got\n\n\n" .. err)
        end
    else
        if not ok then
            code_data = C(code_data.code)
            local ok, err2 = code_data:Analyze(true)
            print(code_data.code)
            error(err)
        end
    end

    return code_data.Analyzer
end

describe("set", function()
    it("should work", function()
        local a = run[[local type a = 1337 | 8888]]:GetValue("a", "typesystem")
        assert.equal(2, a:GetLength())
        assert.equal(1337, a:GetElements()[1].data)
        assert.equal(8888, a:GetElements()[2].data)
    end)

    it("union operator should work", function()
        local a = run[[
            local a: 1337 | 888
            local b: 666 | 777
            local c: a | b
        ]]:GetValue("c", "runtime")
        print(a)
        assert.equal(4, a:GetLength())
        --assert.equal(1337, a:GetElements()[1].data)
        --assert.equal(8888, a:GetElements()[2].data)
        print(a)
    end)
end)