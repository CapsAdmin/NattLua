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
                return self.Bar + v, META.Foo + v
            end

            local obj = setmetatable({Bar = 1}, META)
            local a, b = obj:Test(1)
        ]]

        local obj = analyzer:GetValue("obj", "runtime")

        local a = analyzer:GetValue("a", "runtime")
        local b = analyzer:GetValue("b", "runtime")

        assert.equal(2, a:GetData())
        assert.equal(3, b:GetData())
    end)

    it("empty table should be compatible with metatable", function()
        local analyzer = run[[
            local META = {}
            META.__index = META
            META.Foo = "foo"

            function META:Test()
              --  TPRINT(self.Foo, self.Bar)
            end

            local obj = setmetatable({Bar = "bar"}, META)

            obj:Test()
        ]]

        local META = analyzer:GetValue("META", "runtime")
        local obj = analyzer:GetValue("obj", "runtime")

        --print(META:Get("Foo"))

    end)

    it("__call method should work", function()
        local analyzer = run[[
            local META = {}
            META.__index = META

            function META:__call(a,b,c)
                return a+b+c
            end

            local obj = setmetatable({}, META)

            local lol = obj(100,2,3)
        ]]

        local obj = analyzer:GetValue("obj", "runtime")

        assert.equal(105, analyzer:GetValue("lol", "runtime"):GetData())
    end)

    it("__call method should not mess with scopes", function()
        local analyzer = run[[
            local META = {}
            META.__index = META

            function META:__call(a,b,c)
                return a+b+c
            end

            local a = setmetatable({}, META)(100,2,3)
        ]]

        local a = analyzer:GetValue("a", "runtime")

        assert.equal(105, a:GetData())
    end)

    it("vector test", function()
        local analyzer = run[[
            local Vector = {}
            Vector.__index = Vector

            setmetatable(Vector, {
                __call = function(_, a)
                    return setmetatable({lol = a}, Vector)
                end
            })

            local v = Vector(123).lol
        ]]

        local v = analyzer:GetValue("v", "runtime")
        assert.equal(123, v:GetData())
    end)

    it("vector test2", function()
        local analyzer = run[[
            local Vector = {}
            Vector.__index = Vector

            function Vector.__add(a, b)
                return Vector(a.x + b.x, a.y + b.y, a.z + b.z)
            end

            setmetatable(Vector, {
                __call = function(_, x,y,z)
                    return setmetatable({x=x,y=y,z=z}, Vector)
                end
            })

            local v = Vector(1,2,3) + Vector(100,100,100)
            local x, y, z = v.x, v.y, v.z
        ]]

        local x = analyzer:GetValue("x", "runtime")
        local y = analyzer:GetValue("y", "runtime")
        local z = analyzer:GetValue("z", "runtime")

        assert.equal(101, x:GetData())
        assert.equal(102, y:GetData())
        assert.equal(103, z:GetData())
    end)
end)