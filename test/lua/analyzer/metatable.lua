local T = require("test.helpers")
local run = T.RunCode

test("index function", function()
    local analyzer = run[[
        local t = setmetatable({}, {__index = function() return 1 end})
        local a = t.lol
    ]]

    local a = analyzer:GetValue("a", "runtime")
    equal(1, a:GetData())

    run[[
        local meta = {} as {num = number, __index = self}

        local a = setmetatable({}, meta)

        type_assert(a.num, _ as number)
    ]]
end)

test("basic inheritance", function()
    local analyzer = run[[
        local META = {}
        META.__index = META

        META.Foo = 2
        META.Bar = 0 as number

        function META:Test(v)
            return self.Bar + v, META.Foo + v
        end

        local obj = setmetatable({Bar = 1}, META)
        local a, b = obj:Test(1)
    ]]

    local obj = analyzer:GetValue("obj", "runtime")

    local a = analyzer:GetValue("a", "runtime")
    local b = analyzer:GetValue("b", "runtime")

    equal(2, a:GetData())
    equal(3, b:GetData())
end)

test("__call method", function()
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

    equal(105, analyzer:GetValue("lol", "runtime"):GetData())
end)

test("__call method should not mess with scopes", function()
    local analyzer = run[[
        local META = {}
        META.__index = META

        function META:__call(a,b,c)
            return a+b+c
        end

        local a = setmetatable({}, META)(100,2,3)
    ]]

    local a = analyzer:GetValue("a", "runtime")

    equal(105, a:GetData())
end)

test("vector test", function()
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
    equal(123, v:GetData())
end)

test("vector test2", function()
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

    equal(101, x:GetData())
    equal(102, y:GetData())
    equal(103, z:GetData())
end)

test("interface extensions", function()
    run[[
        local type Vec2 = {x = number, y = number}
        local type Vec3 = {z = number} extends Vec2

        local type Base = {
            Test = function(self): number,
        }

        local type Foo = Base extends {
            SetPos = (function(self, pos: Vec3): nil),
            GetPos = (function(self): Vec3),
        }

        -- have to use as here because {} would not be a subset of Foo
        local x = {} as Foo

        x:SetPos({x = 1, y = 2, z = 3})
        --[==[x:SetPos({x = 1, y = 2, z = 3})
        local a = x:GetPos()
        local z = a.x + 1

        type_assert(z, _ as number)

        local test = x:Test()
        type_assert(test, _ as number)]==]
    ]]
end)

test("error on newindex", function()
    run([[
        type error = function(msg: string)
            assert(type(msg.data) == "string", "msg does not contain a string?")
            error(msg.data)
        end

        local META = {}
        META.__index = META

        function META:__newindex(key, val)
            if key == "foo" then
                error("cannot use " .. key)
            end
        end

        local self = setmetatable({}, META)

        self.foo = true

        -- should error
        self.bar = true
    ]], "cannot use foo")
end)

test("tutorialspoint", function()
    run[[
        mytable = setmetatable({key1 = "value1"}, {
            __index = function(mytable, key)
                if key == "key2" then
                    return "metatablevalue"
                else
                    return mytable[key]
                end
            end
        })

        type_assert(mytable.key1, "value1")
        type_assert(mytable.key2, "metatablevalue")
    ]]

    run[[
        mymetatable = {}
        mytable = setmetatable({key1 = "value1"}, { __newindex = mymetatable })

        type_assert(mytable.key1, "value1")

        mytable.newkey = "new value 2"
        type_assert(mytable.newkey, nil)
        type_assert(mymetatable.newkey, "new value 2")

        mytable.key1 = "new value 1"
        type_assert(mytable.key1, "value1")
        type_assert(mymetatable.newkey1, nil)
    ]]
end)

run[[
    local META = {}

    function META:Foo()
        return 1
    end
    
    function META:Bar()
        return 2
    end

    function META:Faz(a, b)
        return a, b
    end

    local a,b = META:Faz(META:Foo(), META:Bar())
    type_assert(a, 1)
    type_assert(b, 2)
]]

run[[
    local a = setmetatable({c = true}, {
        __index = {
            foo = true,
            bar = 2,
        }
    })
    
    type_assert(rawget(a, "bar"), nil)
    type_assert(rawget(a, "foo"), nil)
    type_assert(rawget(a, "c"), true)
    
    rawset(a, "foo", "hello")
    type_assert(rawget(a, "foo"), "hello")
]]

run[[
    local self = setmetatable({}, {
        __index = setmetatable({foo = true}, {
            __index = {
                bar = true,
            }
        })
    })
    
    type_assert(self.foo, true)
    type_assert(self.bar, true)
]]