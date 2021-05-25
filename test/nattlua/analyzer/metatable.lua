local T = require("test.helpers")
local run = T.RunCode

test("index function", function()
    local analyzer = run[[
        local t = setmetatable({}, {__index = function(self, key) return 1 end})
        local a = t.lol
    ]]

    local a = analyzer:GetLocalOrEnvironmentValue(types.LString("a"), "runtime")
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

    local obj = analyzer:GetLocalOrEnvironmentValue(types.LString("obj"), "runtime")

    local a = analyzer:GetLocalOrEnvironmentValue(types.LString("a"), "runtime")
    local b = analyzer:GetLocalOrEnvironmentValue(types.LString("b"), "runtime")

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

    local obj = analyzer:GetLocalOrEnvironmentValue(types.LString("obj"), "runtime")

    equal(105, analyzer:GetLocalOrEnvironmentValue(types.LString("lol"), "runtime"):GetData())
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

    local a = analyzer:GetLocalOrEnvironmentValue(types.LString("a"), "runtime")

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

    local v = analyzer:GetLocalOrEnvironmentValue(types.LString("v"), "runtime")
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

    local x = assert(analyzer:GetLocalOrEnvironmentValue(types.LString("x"), "runtime"))
    local y = assert(analyzer:GetLocalOrEnvironmentValue(types.LString("y"), "runtime"))
    local z = assert(analyzer:GetLocalOrEnvironmentValue(types.LString("z"), "runtime"))

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

        -- have to use the as operator here because {} would not be a subset of Foo
        local x = _ as Foo

        x:SetPos({x = 1, y = 2, z = 3})
        local a = x:GetPos()
        local z = a.x + 1

        type_assert(z, _ as number)

        local test = x:Test()
        type_assert(test, _ as number)
    ]]
end)

test("error on newindex", function()
    run([[
        local type error = function(msg: string)
            assert(type(msg:GetData()) == "string", "msg has no field a string?")
            error(msg:GetData())
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

run[[
    local META = {}
    META.__index = META

    type META.@Self = {
        foo = {[number] = string},
        i = number,
    }

    local type Foo = META.@Self

    local function test2(x: Foo)
        
    end

    local function test(x: Foo & {extra = boolean | nil})
        type_assert(x.asdf, true) -- x.asdf will __index to META
        x.extra = true
        test2(x as Foo) -- x.extra should not be a valid field in test2
    end

    META.asdf = true

    function META:Lol()
        test(self)
    end
]]

run[[
    local meta = {}
    meta.__index = meta

    function meta:Test()
        return self.foo
    end

    local obj = setmetatable({
        foo = 1
    }, meta)

    type_assert(obj:Test(), 1)
]]

run([[
    local meta = {} as {
        __index = self,
        Test = function(self): string
    }
    meta.__index = meta
    
    function meta:Test()
        return self.foo
    end
    
    local obj = setmetatable({
        foo = 1
    }, meta)
    
    obj:Test()
]], "foo.- is not a subset of")

run([[
    local meta = {} as {
        __index = self, 
        Test = (function(self): number),
        foo = number,
    }
    meta.__index = meta

    function meta:Test()
        return self.foo
    end

    local obj = setmetatable({
        foo = 1
    }, meta)

    type_assert(obj:Test(), _ as number)
]])

run([[
    local meta = {}
    meta.__index = meta

    function meta:foo()
        self.data = self.data + 1
        return self.data
    end

    local function foo()
        return setmetatable({data = 0}, meta)
    end

    local obj = foo()
    type_assert(obj.data, 0)
    type_assert(meta.data, nil)
    type_assert(obj:foo(), 1)
]])

run[[
    local Vector = {}
    Vector.__index = Vector

    type Vector.x = number
    type Vector.y = number
    type Vector.z = number

    function Vector.__add(a: Vector, b: Vector)
        return Vector(a.x + b.x, a.y + b.y, a.z + b.z)
    end

    setmetatable(Vector, {
        __call = function(_, x: number, y: number, z: number)
            return setmetatable({x=x,y=y,z=z}, Vector)
        end
    })

    local newvector = Vector(1,2,3) + Vector(100,100,100)
    type_assert(newvector, _ as {x = number, y = number, z = number})
]]


run([[
    local Vector = {}
    Vector.__index = Vector

    type Vector.x = number
    type Vector.y = number
    type Vector.z = number

    function Vector.__add(a: Vector, b: Vector)
        return Vector(a.x + b.x, a.y + b.y, a.z + b.z)
    end

    setmetatable(Vector, {
        __call = function(_, x: number, y: number, z: number)
            return setmetatable({x=x,y=y,z=z}, Vector)
        end
    })

    local new_vector = Vector(1,2,3) + 4

    type_assert(new_vector, _ as {x = number, y = number, z = number})
]], "4 is not the same type as")

run[[
    type code_ptr = {
        @Name = "codeptr",
        @MetaTable = self,
        [number] = number,
        __add = (function(self | number, number | self): self),
        __sub = (function(self | number, number | self): self)
    }
    
    local x: code_ptr
    local y = x + 50 - 1
    
    type_assert(y, _ as code_ptr)
]]

run[[
    local type tbl = {}
    type tbl.@Name = "blackbox"
    setmetatable<|tbl, {__call = function(self: typeof tbl, tbl: {foo = nil | number}) return tbl:Get(types.LString("foo")) end}|>

    local lol = tbl({foo = 1337})

    type_assert(lol, 1337)
]]

run[[
    local type tbl = {}
    type tbl.__call = function(self: typeof tbl, tbl: {foo = nil | number}) return tbl:Get(types.LString("foo")) end
    setmetatable<|tbl, tbl|>

    local lol = tbl({foo = 1337})
    type_assert(lol, 1337)
]]

run[[
    local meta = {}
    meta.__index = meta

    function meta:Foo(a: number)
        return self.foo + 1
    end

    local function ctor1()
        return setmetatable({foo = 1}, meta)
    end

    local function ctor2()
        local self = {}
        self.foo = 2
        setmetatable(self, meta)
        return self
    end

    §analyzer:AnalyzeUnreachableCode()

    local type ret = return_type<|meta.Foo|>
    type_assert<|ret, 2 | 3|>
]]

run[[
    local META = {}
    META.__index = META

    type META.@Self = {
        Foo = number
    }

    function META:GetBar()
        return 1337
    end

    function META:GetFoo()
        return self.Foo + self:GetBar()
    end

    local s = setmetatable({Foo = 1337}, META)
    type_assert(s:GetFoo(), _ as number)
]]

run[[
    local META = {}
    META.__index = META
    type META.@Self = {parent = number | nil}
    function META:SetParent(parent : number | nil)
        if parent then
            self.parent = parent
            type_assert(self.parent, _ as number)
        else
            self.parent = nil
            type_assert(self.parent, _ as nil)
        end

    type_assert(self.parent, _ as nil | number)
    end
]]

run([[
    local META = {}
    META.__index = META

    type META.@Self = {
        foo = {[number] = string},
        i = number,
    }

    function META:Lol()
        self.foo[self.i] = {"bad type"}
    end
]], "bad type.-is not a subset of string")

run[[
    local function GetSet(tbl: literal any, name: literal string, default: literal any)
        tbl[name] = default as NonLiteral<|default|>
        type tbl.@Self[name] = tbl[name]
        
        tbl["Set" .. name] = function(self: tbl.@Self, val: typeof tbl[name])
            self[name] = val
        end
        
        tbl["Get" .. name] = function(self: tbl.@Self): typeof tbl[name]
            return self[name]
        end
    end

    local META = {}
    META.__index = META
    type META.@Self = {}

    GetSet(META, "Foo", true)

    local self = setmetatable({} as META.@Self, META)
    self:SetFoo(true)
    local b = self:GetFoo()
    type_assert<|b, boolean|>
    type_assert<|self.Foo, boolean|>
]]

run[[
    local META =  {}
    META.__index = META

    type META.@Self = {
        foo = true,
    }

    local function test(x: META.@Self & {bar = false})
        type_assert_superset<|x, {foo = true, bar = false}|>
        type_assert_superset<|META.@Self, {foo = true}|>
    end

]]