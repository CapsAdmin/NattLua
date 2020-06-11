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

describe("function", function()
    it("arguments should work", function()
        local analyzer = run[[
            local function test(a,b,c)
                return a+b+c
            end
            local a = test(1,2,3)
        ]]

        assert.equal(6, analyzer:GetValue("a", "runtime"):GetData())
    end)

    it("arguments should get annotated", function()
        local analyzer = run[[
            local function test(a,b,c)
                return a+c
            end

            test(1,"",3)
        ]]

        local args = analyzer:GetValue("test", "runtime"):GetArguments()
        assert.equal(true, args:Get(1):IsType("number"))
        assert.equal(true, args:Get(2):IsType("string"))
        assert.equal(true, args:Get(3):IsType("number"))

        local rets = analyzer:GetValue("test", "runtime"):GetReturnTypes()
        assert.equal(true, rets:Get(1):IsType("number"))
    end)


    it("arguments and return types are volatile", function()
        local analyzer = run[[
            local function test(a)
                return a
            end

            test(1)
            test("")
        ]]

        local func = analyzer:GetValue("test", "runtime")

        local args = func:GetArguments()
        assert.equal(true, args:Get(1):IsType("number"))
        assert.equal(true, args:Get(1):IsType("string"))

        local rets = func:GetReturnTypes()
        assert.equal(true, rets:Get(1):IsType("number"))
        assert.equal(true, rets:Get(1):IsType("string"))
    end)

    it("which is not explicitly annotated should not dictate return values", function()
        local analyzer = run[[
            local function test(a)
                return a
            end

            test(1)

            local a = test(true)
        ]]

        local val = analyzer:GetValue("a", "runtime")
        print(val)
        assert.equal(true, val:IsType("boolean"))
        assert.equal(true, val:GetData())
        assert.equal(false, val:IsVolatile())
    end)
end)