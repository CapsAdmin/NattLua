local T = require("test.helpers")
local run = T.RunCode
local String = T.String

test("index function", function()
    local analyzer = run[[
        local t = setmetatable({}, {__index = function(self, key) return 1 end})
        local a = t.lol
    ]]

    local a = analyzer:GetLocalOrEnvironmentValue(String("a"), "runtime")
    equal(1, a:GetData())

    run[[
        local meta = {} as {num = number, __index = self}

        local a = setmetatable({}, meta)

        types.assert(a.num, _ as number)
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

    local obj = analyzer:GetLocalOrEnvironmentValue(String("obj"), "runtime")

    local a = analyzer:GetLocalOrEnvironmentValue(String("a"), "runtime")
    local b = analyzer:GetLocalOrEnvironmentValue(String("b"), "runtime")

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

    local obj = analyzer:GetLocalOrEnvironmentValue(String("obj"), "runtime")

    equal(105, analyzer:GetLocalOrEnvironmentValue(String("lol"), "runtime"):GetData())
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

    local a = analyzer:GetLocalOrEnvironmentValue(String("a"), "runtime")

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

    local v = analyzer:GetLocalOrEnvironmentValue(String("v"), "runtime")
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

    local x = assert(analyzer:GetLocalOrEnvironmentValue(String("x"), "runtime"))
    local y = assert(analyzer:GetLocalOrEnvironmentValue(String("y"), "runtime"))
    local z = assert(analyzer:GetLocalOrEnvironmentValue(String("z"), "runtime"))

    equal(101, x:GetData())
    equal(102, y:GetData())
    equal(103, z:GetData())
end)

test("interface extensions", function()
    run[[
        local type Vec2 = {x = number, y = number}
        local type Vec3 = {z = number} extends Vec2

        local type Base = {
            Test = function=(self)>(number),
        }

        local type Foo = Base extends {
            SetPos = function=(self, pos: Vec3)>(nil),
            GetPos = function=(self)>(Vec3),
        }

        -- have to use the as operator here because {} would not be a subset of Foo
        local x = _ as Foo

        x:SetPos({x = 1, y = 2, z = 3})
        local a = x:GetPos()
        local z = a.x + 1

        types.assert(z, _ as number)

        local test = x:Test()
        types.assert(test, _ as number)
    ]]
end)

test("error on newindex", function()
    run([[
        local type error = analyzer function(msg: string)
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

        types.assert(mytable.key1, "value1")
        types.assert(mytable.key2, "metatablevalue")
    ]]

    run[[
        mymetatable = {}
        mytable = setmetatable({key1 = "value1"}, { __newindex = mymetatable })

        types.assert(mytable.key1, "value1")

        mytable.newkey = "new value 2"
        types.assert(mytable.newkey, nil)
        types.assert(mymetatable.newkey, "new value 2")

        mytable.key1 = "new value 1"
        types.assert(mytable.key1, "value1")
        types.assert(mymetatable.newkey1, nil)
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
    types.assert(a, 1)
    types.assert(b, 2)
]]

run[[
    local a = setmetatable({c = true}, {
        __index = {
            foo = true,
            bar = 2,
        }
    })
    
    types.assert(rawget(a, "bar"), nil)
    types.assert(rawget(a, "foo"), nil)
    types.assert(rawget(a, "c"), true)
    
    rawset(a, "foo", "hello")
    types.assert(rawget(a, "foo"), "hello")
]]

run[[
    local self = setmetatable({}, {
        __index = setmetatable({foo = true}, {
            __index = {
                bar = true,
            }
        })
    })
    
    types.assert(self.foo, true)
    types.assert(self.bar, true)
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
        types.assert(x.asdf, true) -- x.asdf will __index to META
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

    types.assert(obj:Test(), 1)
]]

run([[
    local meta = {} as {
        __index = self,
        Test = function=(self)>(string)
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
        Test = function=(self)>(number),
        foo = number,
    }
    meta.__index = meta

    function meta:Test()
        return self.foo
    end

    local obj = setmetatable({
        foo = 1
    }, meta)

    types.assert(obj:Test(), _ as number)
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
    types.assert(obj.data, 0)
    types.assert(meta.data, nil)
    types.assert(obj:foo(), 1)
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
    types.assert(newvector, _ as {x = number, y = number, z = number})
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

    types.assert(new_vector, _ as {x = number, y = number, z = number})
]], "4 is not the same type as")

run[[
    type code_ptr = {
        @Name = "codeptr",
        @MetaTable = self,
        [number] = number,
        __add = function=(self | number, number | self)>(self),
        __sub = function=(self | number, number | self)>(self)
    }
    
    local x: code_ptr
    local y = x + 50 - 1
    
    types.assert(y, _ as code_ptr)
]]

run[[
    local type tbl = {}
    type tbl.@Name = "blackbox"
    setmetatable<|tbl, {__call = analyzer function(self: typeof tbl, tbl: {foo = nil | number}) return tbl:Get(types.LString("foo")) end}|>

    local lol = tbl({foo = 1337})

    types.assert(lol, 1337)
]]

run[[
    local type tbl = {}
    type tbl.__call = analyzer function(self: typeof tbl, tbl: {foo = nil | number}) return tbl:Get(types.LString("foo")) end
    setmetatable<|tbl, tbl|>

    local lol = tbl({foo = 1337})
    types.assert(lol, 1337)
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
    types.assert<|ret, 2 | 3|>
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
    types.assert(s:GetFoo(), _ as number)
]]

run[[
    local META = {}
    META.__index = META
    type META.@Self = {parent = number | nil}
    function META:SetParent(parent : number | nil)
        if parent then
            self.parent = parent
            types.assert(self.parent, _ as number)
        else
            self.parent = nil
            types.assert(self.parent, _ as nil)
        end

    types.assert(self.parent, _ as nil | number)
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
    types.assert<|b, boolean|>
    types.assert<|self.Foo, boolean|>
]]

run[[
    local META =  {}
    META.__index = META

    type META.@Self = {
        foo = true,
    }

    local function test(x: META.@Self & {bar = false})
        types.assert_superset<|x, {foo = true, bar = false}|>
        types.assert_superset<|META.@Self, {foo = true}|>
    end

]]

run[[

    -- class.lua
    -- Compatible with Lua 5.1 (not 5.0).
    local function class(base: literal any, init: literal any)
        local c = {}    -- a new class instance
        if not init and type(base) == 'function' then
           init = base
           base = nil
        elseif type(base) == 'table' then
         -- our new class is a shallow copy of the base class!
           for i,v in pairs(base) do
              c[i] = v
           end
           c._base = base
        end
        -- the class will be the metatable for all its objects,
        -- and they will look up their methods in it.
        c.__index = c
     
        -- expose a constructor which can be called by <classname>(<args>)
        local mt = {}
        mt.__call = function(class_tbl, ...)
            local obj = {}
            setmetatable(obj,c)
            if init then
                init(obj,...)
            else 
            -- make sure that any stuff from the base class is initialized!
            if base and base.init then
            base.init(obj, ...)
            end
            end
            return obj
        end
        c.init = init
        c.is_a = function(self: literal any, klass: literal any)
           local m = getmetatable(self)
           while m do 
              if m == klass then return true end
              m = m._base
           end
           return false
        end
        setmetatable(c, mt)
        return c
     end
    
     
    local Animal = class(function(a: literal any,name: literal any)
        a.name = name
    end)
    
    function Animal:__tostring(): literal string -- we have to say that it's a literal string, otherwise the test won't work
        return self.name..': '..self:speak()
    end
    
    local Dog = class(Animal)
    
    function Dog:speak()
        return 'bark'
    end
    
    local Cat = class(Animal, function(c: literal any,name: literal any,breed: literal any)
        Animal.init(c,name)  -- must init base!
        c.breed = breed
    end)
    
    function Cat:speak()
        return 'meow'
    end
    
    local Lion = class(Cat)
    
    function Lion:speak()
        return 'roar'
    end
        
    local fido = Dog('Fido')
    local felix = Cat('Felix','Tabby')
    local leo = Lion('Leo','African')
    
    types.assert(leo:is_a(Animal), true)
    types.assert(leo:is_a(Cat), true)
    types.assert(leo:is_a(Dog), false)
    types.assert(leo:__tostring(), "Leo: roar")
    types.assert(leo:speak(), "roar")


]]

run[[

    local function class()
        local meta = {}
        meta.__index = meta
        meta.Data = {}
        
        setmetatable(meta, meta)
        
        type meta.@Self = {}
        meta.Data = meta.@Self
    
        function meta:__call(...)
    
            local analyzer function setmetatable(tbl: Table, meta: Table, ...: ...any)
    
                local data = meta:Get(types.LString("Data"))
                
                local constructor = analyzer:Assert(tbl:GetNode(), meta:Get(types.LString("constructor")))
    
                local self_arg = types.Any()
                self_arg.literal_argument = true
                constructor:GetArguments():Set(1, self_arg)
            
                tbl:SetMetaTable(meta)
                analyzer:Assert(tbl:GetNode(), analyzer:Call(constructor, types.Tuple({tbl, ...})))
                analyzer:Assert(tbl:GetNode(), tbl:FollowsContract(data))
                tbl:CopyLiteralness(data)
            
                return tbl
            end
            
    
            return setmetatable({}, meta, ...)
        end
    
        
        return meta
    end
    
    local Animal = class()
    
    Animal.Data.name = "lol" as string
    type Animal.Data.age = number
    --type Animal.Data.name = string
    
    function Animal:constructor(theName: string)
        self.name = theName
        self.age = 123
    end
    
    function Animal:move(distanceInMeters: number | nil)
        distanceInMeters = distanceInMeters or 0
        types.assert(self.name .. " moved " .. distanceInMeters .. "m.", _ as string)
    end
    

]]

run[[
    local type IPlayer = {}
    do
        type IPlayer.@MetaTable = IPlayer
        type IPlayer.@Name = "IPlayer"
        type IPlayer.__index = function<|self: IPlayer, key: string|>
            if key == "IsVisible" then
                return _ as function=(IPlayer, IPlayer)>(1337)
            end
        end
        
        type IPlayer.GetName = function=(IPlayer)>(string)
    
        type IPlayer.@Contract = IPlayer
    end
    
    type Player = function=(entityIndex: number)>(IPlayer)
    
    do
        local ply = Player(1337)
        ply:GetName()
        types.assert(ply:IsVisible(ply), 1337)
    end
]]

run[[
    local type IPlayer = {}
    local type IEntity = {}

    do
        type IEntity.@Name = "IEntity"
        type IEntity.@MetaTable = IEntity
        type IEntity.__index = IEntity
        
        type IEntity.IsVisible = function=(IEntity, target: IEntity)>(boolean)

        type IEntity.@Contract = IEntity
    end

    do
        type IPlayer.@Name = "IPlayer"
        type IPlayer.@MetaTable = IPlayer
        type IPlayer.__index = IPlayer
        type IPlayer.@BaseTable = IEntity
        
        type IPlayer.GetName = function=(IPlayer)>(string)

        type IPlayer.@Contract = IPlayer
    end

    type Player = function=(entityIndex: number)>(IPlayer)


    do
        local ply = Player(1337)
        ply:GetName()
        types.assert(ply:IsVisible(ply), _ as boolean)
    end
]]

run[[
local FALLBACK = "lol"

setmetatable(_G, {
    __index = function(t: literal any, n: literal any)
        return FALLBACK
    end
})

local x = NON_EXISTING_VARIABLE
types.assert(x, FALLBACK)

setmetatable(_G)
]]