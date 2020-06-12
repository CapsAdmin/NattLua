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

describe("metatable", function()
    it("index function should work", function()
        local analyzer = run[[
            local t = setmetatable({}, {__index = function() return 1 end})
            local a = t.lol
        ]]

        local a = analyzer:GetValue("a", "runtime")
        assert.equal(1, a:GetData())
    end)

    it("basic inheritance should work", function()
        local analyzer = run[[
            local META = {}
            META.__index = META

            META.Foo = 2

            function META:Test(v)
                return self.foo + v, META.Foo + v
            end

            local obj = setmetatable({foo = 1}, META)
            local a, b = obj:Test(1)
        ]]

        local obj = analyzer:GetValue("obj", "runtime")

        local a = analyzer:GetValue("a", "runtime")
        local b = analyzer:GetValue("b", "runtime")
        
        assert.equal(2, a:GetData())
        assert.equal(3, b:GetData())
    end) 
        

    it("meta methods should work", function()
        local analyzer = run[[
            local META = {}
            META.__index = META

            function META:__call(a,b,c)
                return a+b+c
            end

            local obj = setmetatable({}, META)
            local a = obj(1,2,3)
        ]]

        local obj = analyzer:GetValue("obj", "runtime")

        local a = analyzer:GetValue("a", "runtime")
        print(a)
--        assert.equal(6, a:GetData())
    end)
do return end
    pending("basic inheritance should work", function()
        local analyzer = run[[
            local Vector = {}
            Vector.__index = Vector
            
            function Vector.__add(a, b)
                return Vector(a.x + b.x, a.y + b.y, a.z + b.z)
            end

            setmetatable(Vector, {
                __call = function(x,y,z) 
                    return setmetatable({x=x,y=y,z=z}, Vector) 
                end
            })

            local v = Vector(1,2,3) + Vector(3,2,1)
        ]]

        local obj = analyzer:GetValue("v", "runtime")
        print(obj)
    end)
end)