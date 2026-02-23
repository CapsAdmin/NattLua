local LString = require("nattlua.types.string").LString

do
	local analyzer = analyze[[
        -- index function
        local t = setmetatable({}, {__index = function(self, key) return 1 end})
        local a = t.lol
    ]]
	local a = analyzer:GetLocalOrGlobalValue(LString("a"))
	equal(1, a:GetData())
end

analyze[[
    local meta = {} as {num = number, __index = self}

    local a = setmetatable({}, meta)

    attest.equal(a.num, _ as number)
]]

do -- basic inheritance
	local analyzer = analyze[[
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
	local obj = analyzer:GetLocalOrGlobalValue(LString("obj"))
	local a = analyzer:GetLocalOrGlobalValue(LString("a"))
	local b = analyzer:GetLocalOrGlobalValue(LString("b"))
	equal(2, a:GetData())
	equal(3, b:GetData())
end

do -- __call method
	local analyzer = analyze[[
        local META = {}
        META.__index = META

        function META:__call(a,b,c)
            return a+b+c
        end

        local obj = setmetatable({}, META)

        local lol = obj(100,2,3)
    ]]
	local obj = analyzer:GetLocalOrGlobalValue(LString("obj"))
	equal(105, analyzer:GetLocalOrGlobalValue(LString("lol")):GetData())
end

do -- __call method should not mess with scopes
	local analyzer = analyze[[
        local META = {}
        META.__index = META

        function META:__call(a,b,c)
            return a+b+c
        end

        local a = setmetatable({}, META)(100,2,3)
    ]]
	local a = analyzer:GetLocalOrGlobalValue(LString("a"))
	equal(105, a:GetData())
end

do -- vector test
	local analyzer = analyze[[
        local Vector = {}
        Vector.__index = Vector

        setmetatable(Vector, {
            __call = function(_, a)
                return setmetatable({lol = a}, Vector)
            end
        })

        local v = Vector(123).lol
    ]]
	local v = analyzer:GetLocalOrGlobalValue(LString("v"))
	equal(123, v:GetData())
end

do -- vector test
	local analyzer = analyze[[
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
	local x = assert(analyzer:GetLocalOrGlobalValue(LString("x")))
	local y = assert(analyzer:GetLocalOrGlobalValue(LString("y")))
	local z = assert(analyzer:GetLocalOrGlobalValue(LString("z")))
	equal(101, x:GetData())
	equal(102, y:GetData())
	equal(103, z:GetData())
end

analyze[[
    -- interface extensions
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

    attest.equal(z, _ as number)

    local test = x:Test()
    attest.equal(test, _ as number)
]]
analyze(
	[[
        -- error on newindex

        local type error = analyzer function(msg: string)
            assert(type(msg:GetData()) == "string", "msg has no key a string?")
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
    ]],
	"cannot use foo"
)
analyze[[
        -- tutorialspoint 

        mytable = setmetatable({key1 = "value1"}, {
            __index = function(mytable, key)
                if key == "key2" then
                    return "metatablevalue"
                else
                    return mytable[key]
                end
            end
        })

        attest.equal(mytable.key1, "value1")
        attest.equal(mytable.key2, "metatablevalue")
    ]]
analyze[[
        -- tutorialspoint 

        mymetatable = {}
        mytable = setmetatable({key1 = "value1"}, { __newindex = mymetatable })

        attest.equal(mytable.key1, "value1")

        mytable.newkey = "new value 2"
        attest.equal(mytable.newkey, nil)
        attest.equal(mymetatable.newkey, "new value 2")

        mytable.key1 = "new value 1"
        attest.equal(mytable.key1, "value1")
        attest.equal(mymetatable.newkey1, nil)
    ]]
analyze[[
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
    attest.equal(a, 1)
    attest.equal(b, 2)
]]
analyze[[
    local a = setmetatable({c = true}, {
        __index = {
            foo = true,
            bar = 2,
        }
    })
    
    attest.equal(rawget(a, "bar"), nil)
    attest.equal(rawget(a, "foo"), nil)
    attest.equal(rawget(a, "c"), true)
    
    rawset(a, "foo", "hello")
    attest.equal(rawget(a, "foo"), "hello")
]]
analyze[[
    local self = setmetatable({}, {
        __index = setmetatable({foo = true}, {
            __index = {
                bar = true,
            }
        })
    })
    
    attest.equal(self.foo, true)
    attest.equal(self.bar, true)
]]
analyze[[
    local META = {}
    META.__index = META

    -- this is just a shorthand for the self argument
    type META.@SelfArgument = {
        foo = {[number] = string},
        i = number,
        @MetaTable = META,
    }

    local function test2(x: META)
        
    end

    local function test(x: META.@SelfArgument & {extra = boolean | nil})
        attest.equal(x.asdf, true) -- x.asdf will __index to META
        x.extra = true
        test2(x as META) -- x.extra should not be a valid field in test2
    end

    META.asdf = true

    -- self argument is applied here
    function META:Lol()
        attest.equal(self.asdf, true)
        attest.equal(self.i, _ as number)
        test(self)
    end

    -- the above is the same as this because of META.@SelfArgument
    function META.Lol(self: META.@SelfArgument)
        attest.equal(self.asdf, true)
        attest.equal(self.i, _ as number)
    end
]]
analyze[[
    local meta = {}
    meta.__index = meta

    function meta:Test()
        return self.foo
    end

    local obj = setmetatable({
        foo = 1
    }, meta)

    attest.equal(obj:Test(), 1)
]]
analyze(
	[[
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
]],
	"foo.- is not a subset of"
)
analyze([[
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
    attest.equal(obj.data, 0)
    attest.equal(meta.data, nil)
    attest.equal(obj:foo(), 1)
]])
analyze[[
    local Vector = {}
    Vector.__index = Vector

    type Vector.x = number
    type Vector.y = number
    type Vector.z = number

    function Vector.__add(a: Vector, b: Vector)
        return Vector(a.x + b.x, a.y + b.y, a.z + b.z)
    end

    setmetatable(Vector, {
        __call = function(_, x: ref number, y: ref number, z: ref number)
            return setmetatable({x=x,y=y,z=z}, Vector)
        end
    })

    local newvector = Vector(1,2,3) + Vector(100,100,100)
    attest.equal(newvector, _ as {x = number, y = number, z = number})
]]
analyze(
	[[
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

    attest.equal(new_vector, _ as {x = number, y = number, z = number})
]],
	"4.-is not a subset of"
)
analyze[[
    local type code_ptr = {
        @Name = "codeptr",
        @MetaTable = self,
        [number] = number,
        __add = function=(self | number, number | self)>(self),
        __sub = function=(self | number, number | self)>(self)
    }
    
    local x: code_ptr
    local y = x + 50 - 1
    
    attest.equal(y, _ as code_ptr)
]]
analyze[[
    local type tbl = {}
    type tbl.@Name = "blackbox"
    setmetatable<|tbl, {__call = analyzer function(self: typeof tbl, tbl: {foo = nil | number}) return tbl:Get(types.ConstString("foo")) end}|>

    local lol = tbl({foo = 1337})

    attest.equal(lol, 1337)
]]
analyze[[
    local type tbl = {}
    type tbl.__call = analyzer function(self: typeof tbl, tbl: {foo = nil | number}) return tbl:Get(types.ConstString("foo")) end
    setmetatable<|tbl, tbl|>

    local lol = tbl({foo = 1337})
    attest.equal(lol, 1337)
]]
analyze[[
    local meta = {}
    meta.__index = meta

    type meta.@SelfArgument = {
        foo = number,
        @MetaTable = meta,
    }
    
    local function ctor1()
        return setmetatable({foo = 1}, meta)
    end
    
    local function ctor2()
        return setmetatable({foo = 2}, meta)
    end
    
    §analyzer:AnalyzeUnreachableCode()
    
    function meta:Foo()
        return self.foo
    end
    
    §analyzer:AnalyzeUnreachableCode()
    
    local type ret = return_type<|meta.Foo|>[1]
    attest.equal<|ret, number|>
]]
analyze[[
    local META = {}
    META.__index = META

    type META.@SelfArgument = {
        Foo = number,
        @MetaTable = META,
    }

    function META:GetBar()
        return 1337
    end

    function META:GetFoo()
        return self.Foo + self:GetBar()
    end

    local s = setmetatable({Foo = 1337 as number}, META)
    attest.equal(s:GetFoo(), _ as number)

    local s = setmetatable({Foo = 1337}, META)
    attest.equal(s:GetFoo(), _ as 2674)
]]
analyze[[
    local META = {}
    META.__index = META
    type META.@SelfArgument = {parent = number | nil, @MetaTable = META}
    function META:SetParent(parent : number | nil)
        if parent then
            self.parent = parent
            attest.equal(self.parent, _ as number)
        else
            self.parent = nil
            attest.equal(self.parent, _ as nil)
        end

    attest.equal(self.parent, _ as nil | number)
    end
]]
analyze(
	[[
    local META = {}
    META.__index = META

    type META.@SelfArgument = {
        foo = {[number] = string},
        i = number,
        @MetaTable = META,
        @Contract = self, -- makes the .foo type immutable
    }

    function META:Lol()
        self.foo[self.i] = {"bad type"}
    end
]],
	"bad type.-is not a subset of string"
)
analyze[[
    local function GetSet(tbl: ref any, name: ref string, default: ref any)
        tbl[name] = default as NonLiteral<|default|>
        type tbl.@SelfArgument[name] = tbl[name]
        
        tbl["Set" .. name] = function(self: tbl.@SelfArgument, val: typeof tbl[name])
            self[name] = val
        end
        
        tbl["Get" .. name] = function(self: tbl.@SelfArgument): typeof tbl[name]
            return self[name]
        end
    end

    local META = {}
    META.__index = META
    type META.@SelfArgument = {@MetaTable = META,@Contract = self,}

    GetSet(META, "Foo", true)

    local self = setmetatable({} , META)
    self:SetFoo(true)
    local b = self:GetFoo()
    attest.equal<|b, boolean|>
    attest.equal<|self.Foo, boolean|>
]]
analyze[[
    local META =  {}
    META.__index = META

    type META.@SelfArgument = {
        foo = true,
    }

    local function test(x: META.@SelfArgument & {bar = false})
        attest.superset_of<|x, {foo = true, bar = false}|>
        attest.superset_of<|META.@SelfArgument, {foo = true}|>
    end

]]
analyze[[

    -- class.lua
    -- Compatible with Lua 5.1 (not 5.0).
    local function class(base: ref any, init: ref any)
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
        c.is_a = function(self: ref any, klass: ref any)
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
    
     
    local Animal = class(function(a: ref any,name: ref any)
        a.name = name
    end)
    
    function Animal:__tostring(): ref string -- we have to say that it's a literal string, otherwise the test won't work
        return self.name..': '..self:speak()
    end
    
    local Dog = class(Animal)
    
    function Dog:speak()
        return 'bark'
    end
    
    local Cat = class(Animal, function(c: ref any,name: ref any,breed: ref any)
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
    
    attest.equal(leo:is_a(Animal), true)
    attest.equal(leo:is_a(Cat), true)
    attest.equal(leo:is_a(Dog), false)
    attest.equal(leo:__tostring(), "Leo: roar")
    attest.equal(leo:speak(), "roar")
]]
analyze[[
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
    
    local type Player = function=(entityIndex: number)>(IPlayer)
    
    do
        local ply = Player(1337)
        ply:GetName()
        attest.equal(ply:IsVisible(ply), 1337)
    end
]]
pending[[
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
        type IPlayer.__index = function(s, k) 
            local val = rawget(IPlayer, k)
            if val ~= nil then
                return val
            end

            return rawget(IEntity, k)
        end
        
        type IPlayer.GetName = function=(IPlayer)>(string)

        type IPlayer.@Contract = IPlayer
    end

    local type Player = function=(entityIndex: number)>(IPlayer)


    do
        local ply = Player(1337)
        ply:GetName()
        attest.equal(ply:IsVisible(ply), _ as boolean)
    end
]]
analyze[[
    local FALLBACK = "lol"

    setmetatable(_G, {
        __index = function(t: ref any, n: ref any)
            return FALLBACK
        end
    })

    local x = NON_EXISTING_VARIABLE
    attest.equal(x, FALLBACK)

    setmetatable(_G)
]]
analyze[[
    setmetatable(_G, {__index = function(self: ref any, key: ref any) return "LOL" end})
    attest.equal(DUNNO, "LOL")
    setmetatable(_G)
]]
analyze[[
    local META = {}
    META.__index = META
    type META.@Name = "Syntax"
    type META.@SelfArgument = {
        Keywords = Map<|string, true|>,
        @MetaTable = META,
    }
    
    function META.New() 
        local self = setmetatable({
            Keywords = {},
        }, META)
        return self
    end
    
    
    function META:AddSymbols(tbl: List<|string|>)
        
    end
    
    function META:AddKeywords(tbl: List<|string|>)
        self:AddSymbols(tbl)
        for _, str in ipairs(tbl) do
            self.Keywords[str] = true
        end
    end
    
    local Syntax = META.New
    local function lol()
        local runtime = Syntax()
    
        local s = {}
        runtime:AddKeywords(s)
    
        return runtime
    end
    lol()

]]
analyze(
	[[

    local type meta = {}
    type meta.@SelfArgument = {
        pointer = boolean,
        ffi_name = string,
        fields = {[string] = number | self | string},
        @MetaTable = meta,
    }
    
    function meta:__index<|key: string|>
        local type val = rawget<|self, key|>
    
        if val then return val end
    
        type_error<|("%q has no member named %q"):format(self.ffi_name, key), 2|>
    end
    
    function meta:__add<|other: number|>
        if self.pointer then return self end
    
        type_error<|("attempt to perform arithmetic on %q and %q"):format(self.ffi_name, TypeName<|other|>), 2|>
    end
    
    function meta:__sub<|other: number|>
        if self.pointer then return self end
    
        type_error<|("attempt to perform arithmetic on %q and %q"):format(self.ffi_name, TypeName<|other|>), 2|>
    end
    
    function meta:__len<||>
        type_error<|("attempt to get length of %q"):format(self.ffi_name), 2|>
    end
    
    local function CData<|data: Table, name: string, pointer: boolean|>
        local type self = setmetatable<|{
            pointer = pointer,
            ffi_name = name,
            fields = data,
        }, meta|>
        return self
    end
    
    local x = _ as CData<|{foo = number}, "struct 66", false|>
    local y = x + 2

]],
	"attempt to perform arithmetic on"
)
analyze[[
    local type meta = {}
    type meta.__index = meta
    type meta.@SelfArgument = {value = {[any] = any}, @MetaTable = meta}

    function meta:__index<|key: any|>
        local obj = setmetatable<|{value = {[any] = any}}, meta|>
        self.value[key] = obj | self.value[key]
        return obj | any
    end

    function meta:__newindex<|key: any, val: any|>
        self.value[key] = self.value[key] | val
    end

    function meta:__add<|other: any|>
        return Widen(other)
    end

    function meta:__concat<|other: any|>
        return Widen(other)
    end

    function meta:__len<||>
        return number
    end

    function meta:__unm<||>
        return any
    end

    function meta:__bnot<||>
        return any
    end

    function meta:__sub<|b: any|>
        return Widen(b)
    end

    function meta:__mul<|b: any|>
        return Widen(b)
    end

    function meta:__div<|b: any|>
        return Widen(b)
    end

    function meta:__idiv<|b: any|>
        return Widen(b)
    end

    function meta:__mod<|b: any|>
        return Widen(b)
    end

    function meta:__pow<|b: any|>
        return Widen(b)
    end

    function meta:__band<|b: any|>
        return Widen(b)
    end

    function meta:__bor<|b: any|>
        return Widen(b)
    end

    function meta:__bxor<|b: any|>
        return Widen(b)
    end

    function meta:__shl<|b: any|>
        return Widen(b)
    end

    function meta:__shr<|b: any|>
        return Widen(b)
    end

    function meta:__eq<|b: any|>
        return boolean
    end

    function meta:__lt<|b: any|>
        return Widen(b)
    end

    function meta:__le<|b: any|>
        return Widen(b)
    end

    function meta:__call<|...: ...any|>
        local ret = setmetatable<|{value = {[any] = any}}, meta|>
        self.value = function=((...))>((ret)) | self.value
        return ret
    end

    local function InferenceObject<||>
        return setmetatable<|{value = {[any] = any}}, meta|>
    end

    local type lib = InferenceObject<||>
    lib.foo.bar = true
    lib.foo(1, 2, 3)
    attest.equal<|
        lib,
        {
            ["value"] = {
                [any] = any,
                ["foo"] = any | {
                    ["value"] = {
                        [any] = any,
                        ["bar"] = any | true,
                    } as {[any] = any},
                } | {
                    ["value"] = {
                        [any] = any,
                        ["value"] = any | self | function=(1)>({["value"] = {[any] = any}}),
                    } as {[any] = any},
                },
            } as {[any] = any},
        }
    |>
]]
analyze[[
    local meta = {}
    meta.__index = meta
    type meta.@SelfArgument = {
        type = number,
    }

    function meta:lol(foo: self.type)
        return foo + 1
    end

    local s = setmetatable({type = 1}, meta)
    attest.equal(s:lol(1), _  as number)
]]
analyze[[
    type Player = nil
    type Entity = nil
    type Enemy = nil


    local Entity = {}
    type Entity.@SelfArgument = {x = number, y = number, id = string}
    Entity.__index = Entity

    function Entity.New(x: number, y: number)
        local self: Entity.@SelfArgument = {x = x, y = y, id = tostring({})}
        setmetatable2(self, Entity)
        return self
    end

    function Entity:GetPosition(): (number, number)
        return self.x, self.y
    end

    function Entity:Move(dx: number, dy: number)
        self.x = self.x + dx
        self.y = self.y + dy
    end

    function Entity:GetID(): string
        return self.id
    end

    -- Player class deriving from Entity
    local Player = {}
    type Player.@SelfArgument = Entity.@SelfArgument & {
        health = number,
        name = string,
    }

    function Player:__index(key)
        if Player[key] ~= nil then return Player[key] end

        if Entity[key] ~= nil then return Entity[key] end
    end

    function Player.New(x: number, y: number, name: string)
        local self: Player.@SelfArgument = {x = x, y = y, id = tostring({}), health = 100, name = name}
        setmetatable2(self, Player)
        return self
    end

    function Player:GetHealth(): number
        return self.health
    end

    function Player:SetHealth(health: number)
        self.health = health
    end

    function Player:GetName(): string
        return self.name
    end

    -- Enemy class deriving from Entity
    local Enemy = {}
    type Enemy.@SelfArgument = Entity.@SelfArgument & {
        damage = number,
        enemy_type = string,
    }

    function Enemy:__index(key)
        if Enemy[key] ~= nil then return Enemy[key] end

        if Entity[key] ~= nil then return Entity[key] end
    end

    function Enemy.New(x: number, y: number, enemy_type: string)
        local self: Enemy.@SelfArgument = {x = x, y = y, id = tostring({}), damage = 10, enemy_type = enemy_type}
        setmetatable2(self, Enemy)
        return self
    end

    function Enemy:GetDamage(): number
        return self.damage
    end

    function Enemy:SetDamage(damage: number)
        self.damage = damage
    end

    function Enemy:GetEnemyType(): string
        return self.enemy_type
    end

    -- Example usage:
    do
        local player = Player.New(0, 0, "Hero")
        player:Move(5, 5)
        local enemy = Enemy.New(10, 10, "Goblin")
        enemy:Move(-2, 3)
        attest.equal(player:GetName(), _ as string) -- Hero
        attest.equal(player:GetHealth(), _ as number) -- 100
        attest.equal(player:GetID(), _ as string) -- unique id
        attest.equal(enemy:GetEnemyType(), _ as string) -- Goblin 
        attest.equal(enemy:GetDamage(), _ as number) -- 10
        attest.equal(enemy:GetID(), _ as string) -- unique id
    end
]]
pending[[
    local class = require("nattlua.other.class")
    local META = class.CreateTemplate("Animal")
    type META.@SelfArgument = {
        Foo = true,
        callback = nil | function=(self: self)>(number),
    }
    META:GetSet("Name", "Unknown")

    function META:Test()
        self.test = self.test + 1
        return self.test
    end

    META:AddInitializer(function(init)
        init.test = 1337 as number
    end)

    function META:Call()
        if self.callback then return self:callback() end

        return _ as number
    end

    local cb = function(self: META.@SelfArgument)
        attest.equal(self.Name, _ as string)
        return 1
    end
    local obj = META.NewObject({Name = "Dog", Foo = true, callback = cb})
    attest.equal(obj.Name, _ as string)
    attest.equal(obj.test, _ as number)
    attest.equal(obj.Foo, true)
    attest.equal(obj:Test(), _ as number)
    attest.equal(obj:Call(), _ as number)
]]
-- Test 1: Basic @NewMetaTable - self type is inferred from what setmetatable receives
analyze[[
	local META = {}
	META.__index = META
	

	function META:GetFoo()
		return self.foo
	end

	local obj = setmetatable({foo = 1}, META)
	attest.equal(obj:GetFoo(), 1)
]]
-- Test 2: Multiple fields
analyze[[
	local META = {}
	META.__index = META
	

	function META:GetX()
		return self.x
	end

	function META:GetY()
		return self.y
	end

	local obj = setmetatable({x = 1, y = 2}, META)
	attest.equal(obj:GetX(), 1)
	attest.equal(obj:GetY(), 2)
]]
-- Test 3: Mutation via methods
analyze[[
	local META = {}
	META.__index = META
	

	function META:SetFoo(val: number)
		self.foo = val
	end

	function META:GetFoo()
		return self.foo
	end

	local obj = setmetatable({foo = 0 as number}, META)
	obj:SetFoo(42)
	attest.equal(obj:GetFoo(), _ as number)
]]
-- Test 4: __add metamethod
analyze[[
	local META = {}
	META.__index = META
	

	function META.__add(a, b)
		return setmetatable({x = a.x + b.x, y = a.y + b.y}, META)
	end

	function META:GetX()
		return self.x
	end

	local a = setmetatable({x = 1, y = 2}, META)
	local b = setmetatable({x = 10, y = 20}, META)
	local c = a + b
	attest.equal(c:GetX(), 11)
]]
-- Test 5: __call metamethod as constructor
analyze[[
	local META = {}
	META.__index = META
	

	function META:GetLol()
		return self.lol
	end

	setmetatable(META, {
		__call = function(self, val: number)
			return setmetatable({lol = val}, META)
		end,
	})

	local obj = META(123)
	attest.equal(obj:GetLol(), _ as number)
]]
-- Test 6: Constructor function pattern
analyze[[
	local META = {}
	META.__index = META
	

	function META.New(x: number, y: number)
		return setmetatable({x = x, y = y}, META)
	end

	function META:GetX()
		return self.x
	end

	local obj = META.New(1, 2)
	attest.equal(obj:GetX(), _ as number)
]]
-- Test 7: Method chaining
analyze[[
	local META = {}
	META.__index = META
	

	function META:Foo()
		return 1
	end

	function META:Bar()
		return 2
	end

	local obj = setmetatable({}, META)
	attest.equal(obj:Foo(), 1)
	attest.equal(obj:Bar(), 2)
]]
-- Test 8: Method returning self for chaining
analyze[[
	local META = {}
	META.__index = META
	

	function META:SetX(x: number)
		self.x = x
		return self
	end

	function META:GetX()
		return self.x
	end

	local obj = setmetatable({x = 0 as number, y = 0 as number}, META)
	obj:SetX(5)
	attest.equal(obj:GetX(), _ as number)
]]
-- Test 9: Method accessing data from another instance
analyze[[
	local META = {}
	META.__index = META
	

	function META:GetData()
		return self.data
	end

	function META:SetData(val: number)
		self.data = val
	end

	local a = setmetatable({data = 10 as number}, META)
	local b = setmetatable({data = 20 as number}, META)
	attest.equal(a:GetData(), _ as number)
	attest.equal(b:GetData(), _ as number)
]]
-- Test 10: Basic inheritance with setmetatable chaining
analyze[[
	local Entity = {}
	Entity.__index = Entity

	function Entity.New(x: number, y: number)
		return setmetatable({x = x, y = y, id = tostring({})}, Entity)
	end

	function Entity:GetPosition(): (number, number)
		return self.x, self.y
	end

	function Entity:GetID(): string
		return self.id
	end

	local Player = {}
	Player.__index = Player
	setmetatable(Player, {__index = Entity})

	function Player.New(x: number, y: number, name: string)
		return setmetatable({x = x, y = y, id = tostring({}), health = 100 as number, name = name}, Player)
	end

	function Player:GetHealth(): number
		return self.health
	end

	function Player:GetName(): string
		return self.name
	end

	local player = Player.New(0, 0, "Hero")
	attest.equal(player:GetName(), _ as string)
	attest.equal(player:GetHealth(), _ as number)
	-- Player should also have Entity methods via __index chain
	attest.equal(player:GetID(), _ as string)
]]
-- Test 11: __tostring metamethod
analyze[[
	local META = {}
	META.__index = META
	

	function META.__tostring(self)
		return "MyObj(" .. tostring(self.x) .. ")"
	end

	function META:GetX()
		return self.x
	end

	local obj = setmetatable({x = 42}, META)
	attest.equal(tostring(obj), "MyObj(42)")
	attest.equal(obj:GetX(), 42)
]]
-- Test 12: __len metamethod
analyze[[
	local META = {}
	META.__index = META
	

	function META.__len(self)
		return self.size
	end

	local obj = setmetatable({size = 10}, META)
	attest.equal(#obj, 10)
]]
-- Test 13: __concat metamethod
analyze[[
	local META = {}
	META.__index = META
	

	function META.__concat(a, b)
		return setmetatable({val = a.val .. b.val}, META)
	end

	function META:GetVal()
		return self.val
	end

	local a = setmetatable({val = "hello"}, META)
	local b = setmetatable({val = "world"}, META)
	local c = a .. b
	attest.equal(c:GetVal(), "helloworld")
]]
-- Test 14: __eq metamethod
analyze[[
	local META = {}
	META.__index = META
	

	function META.__eq(a, b)
		return a.id == b.id
	end

	local a = setmetatable({id = 1}, META)
	local b = setmetatable({id = 1}, META)
	attest.equal(a == b, true)
]]
-- Test 15: __newindex metamethod
analyze[[
	local META = {}
	META.__index = META
	

	local storage = {}

	function META.__newindex(self, key, val)
		storage[key] = val
	end

	local obj = setmetatable({}, META)
	obj.foo = 123
	attest.equal(storage.foo, 123)
]]
-- Test 16: Empty table with methods only (no fields from setmetatable)
analyze[[
	local META = {}
	META.__index = META
	

	function META:Hello()
		return "hello"
	end

	local obj = setmetatable({}, META)
	attest.equal(obj:Hello(), "hello")
]]
-- Test 17: Multiple setmetatable calls merge fields
analyze[[
	local META = {}
	META.__index = META
	

	function META:GetA()
		return self.a
	end

	function META:GetB()
		return self.b
	end

	local obj1 = setmetatable({a = 1}, META)
	local obj2 = setmetatable({a = 2, b = 3}, META)
	attest.equal(obj1:GetA(), 1)
	attest.equal(obj2:GetB(), 3)
]]
-- Test 18: @Self and @NewMetaTable should not conflict (Self takes precedence)
analyze[[
	local META = {}
	META.__index = META
	type META.@SelfArgument = {foo = number, @MetaTable = META}

	function META:GetFoo()
		return self.foo
	end

	local obj = setmetatable({foo = 42}, META)
	attest.equal(obj:GetFoo(), 42)
]]
-- Test 19: Three-level inheritance (Base -> Mid -> Leaf)
analyze[[
	local Base = {}
	Base.__index = Base

	function Base.New(id: string)
		return setmetatable({id = id}, Base)
	end

	function Base:GetID(): string
		return self.id
	end

	local Mid = {}
	Mid.__index = Mid
	setmetatable(Mid, {__index = Base})

	function Mid.New(id: string, level: number)
		return setmetatable({id = id, level = level}, Mid)
	end

	function Mid:GetLevel(): number
		return self.level
	end

	local Leaf = {}
	Leaf.__index = Leaf
	setmetatable(Leaf, {__index = Mid})

	function Leaf.New(id: string, level: number, name: string)
		return setmetatable({id = id, level = level, name = name}, Leaf)
	end

	function Leaf:GetName(): string
		return self.name
	end

	local leaf = Leaf.New("abc", 5, "test")
	attest.equal(leaf:GetName(), _ as string)
	attest.equal(leaf:GetLevel(), _ as number)
	attest.equal(leaf:GetID(), _ as string)
]]
-- Test 20: Method override in child class
analyze[[
	local Base = {}
	Base.__index = Base

	function Base:Type()
		return "base"
	end

	local Child = {}
	Child.__index = Child
	setmetatable(Child, {__index = Base})

	function Child:Type()
		return "child"
	end

	local b = setmetatable({}, Base)
	local c = setmetatable({}, Child)
	attest.equal(b:Type(), "base")
	attest.equal(c:Type(), "child")
]]
-- Test 21: Inline class pattern with GetSet (manual, no library)
analyze[[
	local META = {}
	META.__index = META
	

	META.Foo = 0
	META["SetFoo"] = function(self, val: number)
		self.Foo = val
		return self
	end
	META["GetFoo"] = function(self): number
		return self.Foo
	end

	META.Bar = ""
	META["SetBar"] = function(self, val: string)
		self.Bar = val
		return self
	end
	META["GetBar"] = function(self): string
		return self.Bar
	end

	local obj = setmetatable({Foo = 0 as number, Bar = "" as string}, META)
	obj:SetFoo(42)
	attest.equal(obj:GetFoo(), _ as number)
	obj:SetBar("hello")
	attest.equal(obj:GetBar(), _ as string)
]]
-- Test 22: GetSet-style helper function with @NewMetaTable
analyze[[
	local function GetSet(META: ref any, name: ref string, default: ref any)
		META[name] = default
		META["Set" .. name] = function(self, val: NonLiteral<|default|>)
			self[name] = val
			return self
		end
		META["Get" .. name] = function(self): NonLiteral<|default|>
			return self[name]
		end
	end

	local META = {}
	META.__index = META
	

	GetSet(META, "Health", 0 as number)
	GetSet(META, "Name", "" as string)

	local obj = setmetatable({Health = 0 as number, Name = "" as string}, META)
	obj:SetHealth(100)
	attest.equal(obj:GetHealth(), _ as number)
	obj:SetName("Bob")
	attest.equal(obj:GetName(), _ as string)
]]
-- Test 23: CreateTemplate-like factory with @NewMetaTable
analyze[[
	local function CreateTemplate()
		local META = {}
		META.__index = META
		

		function META.GetSet(META: ref META, name: ref string, default: ref any)
			META[name] = default
			META["Set" .. name] = function(self, val: NonLiteral<|default|>)
				self[name] = val
				return self
			end
			META["Get" .. name] = function(self): NonLiteral<|default|>
				return self[name]
			end
		end

		function META.NewObject(init)
			return setmetatable(init, META)
		end

		return META
	end

	local META = CreateTemplate()
	META:GetSet("X", 0 as number)
	META:GetSet("Y", 0 as number)

	function META:Length()
		return (self.X * self.X + self.Y * self.Y) ^ 0.5
	end

	local v = META.NewObject({X = 3 as number, Y = 4 as number})
	attest.equal(v:GetX(), _ as number)
	attest.equal(v:GetY(), _ as number)
	v:SetX(10)
	attest.equal(v:GetX(), _ as number)
]]
-- Test 24: class library pattern with GetSet and NewObject
analyze[[
	local class = {}

	function class.CreateTemplate(type_name: ref string)
		local META = {}
		META.Type = type_name
		META.__index = META
		

		function META.GetSet(META: ref META, name: ref string, default: ref any)
			META[name] = default
			META["Set" .. name] = function(self, val: NonLiteral<|default|>)
				self[name] = val
				return self
			end
			META["Get" .. name] = function(self): NonLiteral<|default|>
				return self[name]
			end
		end

		local on_initialize = {}

		function META.NewObject(init)
			for _, func in ipairs(on_initialize) do
				func(init)
			end
			return setmetatable(init, META)
		end

		function META.AddInitializer(_, func)
			table.insert(on_initialize, func)
		end

		return META
	end

	-- Create a Vector type using the class pattern
	local Vector = class.CreateTemplate("vector")
	Vector:GetSet("X", 0 as number)
	Vector:GetSet("Y", 0 as number)
	Vector:GetSet("Z", 0 as number)

	function Vector.New(x: number, y: number, z: number)
		return Vector.NewObject({
			Type = Vector.Type,
			X = x,
			Y = y,
			Z = z,
		})
	end

	function Vector:Length()
		return (self.X * self.X + self.Y * self.Y + self.Z * self.Z) ^ 0.5
	end

	function Vector:Scale(factor: number)
		self.X = self.X * factor
		self.Y = self.Y * factor
		self.Z = self.Z * factor
		return self
	end

	local v = Vector.New(1, 2, 3)
	attest.equal(v:GetX(), _ as number)
	attest.equal(v:GetY(), _ as number)
	attest.equal(v:GetZ(), _ as number)
	attest.equal(v:Length(), _ as number)
	v:SetX(10)
	attest.equal(v:GetX(), _ as number)
]]
-- Test 25: Two types from same CreateTemplate factory
analyze[[
	local class = {}

	function class.CreateTemplate(type_name: ref string)
		local META = {}
		META.Type = type_name
		META.__index = META
		

		function META.GetSet(META: ref META, name: ref string, default: ref any)
			META[name] = default
			META["Set" .. name] = function(self, val: NonLiteral<|default|>)
				self[name] = val
				return self
			end
			META["Get" .. name] = function(self): NonLiteral<|default|>
				return self[name]
			end
		end

		function META.NewObject(init)
			return setmetatable(init, META)
		end

		return META
	end

	-- Two independent types from the same factory
	local TNumber = class.CreateTemplate("number")
	TNumber:GetSet("Data", 0 as number)

	function TNumber.New(data: number)
		return TNumber.NewObject({Type = TNumber.Type, Data = data})
	end

	function TNumber:IsZero()
		return self.Data == 0
	end

	local TString = class.CreateTemplate("string")
	TString:GetSet("Data", "" as string)

	function TString.New(data: string)
		return TString.NewObject({Type = TString.Type, Data = data})
	end

	function TString:IsEmpty()
		return self.Data == ""
	end

	local n = TNumber.New(42)
	attest.equal(n:GetData(), _ as number)

	local s = TString.New("hello")
	attest.equal(s:GetData(), _ as string)
]]
-- Test 26: GetSet with boolean (IsSet pattern)
analyze[[
	local META = {}
	META.__index = META
	

	-- IsSet pattern: getter is "Is" prefix instead of "Get"
	META.Active = false
	META["SetActive"] = function(self, val: boolean)
		self.Active = val
		return self
	end
	META["IsActive"] = function(self): boolean
		return self.Active
	end

	META.Name = ""
	META["SetName"] = function(self, val: string)
		self.Name = val
		return self
	end
	META["GetName"] = function(self): string
		return self.Name
	end

	local obj = setmetatable({Active = false as boolean, Name = "" as string}, META)
	obj:SetActive(true)
	attest.equal(obj:IsActive(), _ as boolean)
	obj:SetName("test")
	attest.equal(obj:GetName(), _ as string)
]]
-- Test 27: GetSet with chained SetX calls returning self
analyze[[
	local META = {}
	META.__index = META
	

	META.X = 0 as number
	META["SetX"] = function(self: META, val: number)
		self.X = val
		return self
	end
	META["GetX"] = function(self: META): number
		return self.X
	end

	META.Y = 0 as number
	META["SetY"] = function(self: META, val: number)
		self.Y = val
		return self
	end
	META["GetY"] = function(self: META): number
		return self.Y
	end

	local obj = setmetatable({X = 0 as number, Y = 0 as number}, META)
	local result = obj:SetX(10):SetY(20)
	attest.equal(result:GetX(), _ as number)
	attest.equal(result:GetY(), _ as number)
]]
-- Test 28: class pattern with inheritance via setmetatable
analyze[[
	local class = {}

	function class.CreateTemplate(type_name: ref string)
		local META = {}
		META.Type = type_name
		META.__index = META
		

		function META.GetSet(META: ref META, name: ref string, default: ref any)
			META[name] = default
			META["Set" .. name] = function(self, val: NonLiteral<|default|>)
				self[name] = val
				return self
			end
			META["Get" .. name] = function(self): NonLiteral<|default|>
				return self[name]
			end
		end

		function META.NewObject(init)
			return setmetatable(init, META)
		end

		return META
	end

	-- Base entity type
	local Entity = class.CreateTemplate("entity")
	Entity:GetSet("Pos", 0 as number)
	Entity:GetSet("Id", "" as string)

	function Entity.New(pos: number, id: string)
		return Entity.NewObject({Type = Entity.Type, Pos = pos, Id = id})
	end

	-- Player extends Entity
	local Player = class.CreateTemplate("player")
	Player:GetSet("Name", "" as string)
	Player:GetSet("Health", 0 as number)
	setmetatable(Player, {__index = Entity})

	function Player.New(pos: number, id: string, name: string, health: number)
		return Player.NewObject({Type = Player.Type, Pos = pos, Id = id, Name = name, Health = health})
	end

	function Player:IsAlive()
		return self.Health > 0
	end

	local p = Player.New(100, "p1", "Hero", 100)
	attest.equal(p:GetName(), _ as string)
	attest.equal(p:GetHealth(), _ as number)
	-- Should also access Entity methods via __index chain
	attest.equal(p:GetPos(), _ as number)
	attest.equal(p:GetId(), _ as string)
]]
analyze[[
    local META = {}
    META.__index = META

    type META.@SelfArgument = {
        Position = number,
        @MetaTable = META,
    }

    local function GetStringSlice(start: number)
    end

    function META:IsString(str: string, offset: number | nil)
        offset = offset or 0
        GetStringSlice(self.Position + offset)
        GetStringSlice(self.Position)
        return math.random() > 0.5
    end


    local function ReadMultilineString(lexer: META.@SelfArgument)
        -- PushTruthy/FalsyExpressionContext leak to calls
        if lexer:IsString("[", 0) or lexer:IsString("[", 1) then
        end
    end

]]
analyze[[
    local META = {}
    META.__index = META
    type META.@SelfArgument = {parent = number | nil}
    function META:SetParent(parent : number | nil)
        if parent then
            self.parent = parent
        else
            -- test BaseType:UpvalueReference collision with object and upvalue
            attest.equal(self.parent, _ as nil | number)
        end
    end
]]
analyze[[
    local meta = {}
    meta.__index = meta
    type meta.@SelfArgument = {
        on_close = nil | function=(self)>(),
        on_receive = nil | function=(self, string, number, number)>(),
        @Name = "TSocket",
        @MetaTable = meta,
    }

    local function create()
        return setmetatable({}, meta)
    end

    function meta:close()
        if self.on_close then self:on_close() end
    end

    function meta:receive_from(size: number)
        return self:receive(size)
    end

    function meta:receive(size: number)
        if self.on_receive then return self:on_receive("hello", 1, size) end

        if math.random() > 0.5 then self:close() end
    end
]]
analyze[[
    local META = {}

    function META:__index(key)
        return META[key]
    end

    type META.@SelfArgument = {
        comment_escape = false | string,
        @MetaTable = META,
    }

    function META:IsString(str: string, offset: number | nil): boolean
        offset = offset or 0
        return _  as boolean
    end

    function META:ReadRemainingCommentEscape()
        if self.comment_escape and self:IsString(self.comment_escape) then
            local x = #self.comment_escape
        end

        return false
    end
]]
analyze[[
    local function IsString(offset: number | nil)
        offset = 1
        return true
    end

    local comment_escape = _  as false | string

    if comment_escape and IsString() then local x = #comment_escape end
]]
analyze[[
    local META = {}
    META.__index = META
    type META.@SelfArgument = {
        comment_escape = false | string,
        @MetaTable = META,
    }

    function META:IsString(str: number) end

    local self = _  as META.@SelfArgument
    assert(self.comment_escape)
    self:IsString(1)
    assert(self.comment_escape)
]]
analyze[==[
    local class = {}
    function class.CreateTemplate(name)
        local META = {}
        META.Type = name
        META.__index = META
        --[[#type META.@SelfArgument = {}]]
        function META:GetSet(name, default)
            self[name] = default
            --[[#type self.@SelfArgument[name] = default ]]
        end
        return META
    end
    local T = class.CreateTemplate("test")
    T:GetSet("Value", nil)
]==]
analyze[[
    local socket = {}

    function socket.create()
        if _  as boolean then return nil, "test" end

        return _  as number
    end

    local M = {}

    do
        local meta = {}
        meta.__index = meta
        type meta.@SelfArgument = {hello = boolean}

        function M.create(family: string)
            local fd, err, num = socket.create()

            if not fd then return fd, err, num end

            return setmetatable({hello = true}, meta)
        end

        function meta:accept()
            if math.random() > 0.5 then
                local client = setmetatable({hello = false}, meta)
                return client
            end
        end

        function meta:read()
            return "foo"
        end
    end

    local client = M.create("info.family")

    if client then
        local other = assert(client:accept())
        local test = client:read()
    end
]]
analyze[[
    local META =  {}
    META.__index = META

    type META.@SelfArgument = {
        foo = true,
    }

    local type x = META.@SelfArgument & {bar = false}
    attest.equal<|x, {foo = true, bar = false}|>
    attest.equal<|META.@SelfArgument, _ as {foo = true}|>
]]
analyze[[
    local META = {}
    META.__index = META
    type META.@SelfArgument = {}

    function META.GetSet(name: ref string, default: ref any)
        META[name] = default
        type META.@SelfArgument[name] = META[name]
    end

    META.GetSet("Name", nil as nil | META.@SelfArgument)
    META.GetSet("Literal", false)

    function META:SetName(name: META.@SelfArgument)
        self.Name = name
    end
]]
analyze[[
    local META = {}
    META.__index = META
    type META.@SelfArgument = {}

    function META.GetSet<|allowed: any|>(name: ref string, default: ref any)
        META[name] = default as allowed
        type META.@SelfArgument[name] = allowed
    end

    META.GetSet<|nil | META.@SelfArgument|>("Name", nil)
    META.GetSet<|boolean|>("Literal", false)

    function META:SetName(name: META.@SelfArgument)
        self.Name = name
    end
]]
analyze[[
    local META = {}
    META.__index = META
    type META.@SelfArgument = {
        Foo = boolean,
        Bar = boolean,
        @MetaTable = self,
        @Contract = self,
    }

    local function get_base()
        local m = copy<|META|>
        m.@MetaTable = m
        m.@Contract = m
        return m
    end

    do
        local META = get_base()
        type META.@SelfArgument.Test = number
        type META.@SelfArgument.tbl = nil | List<|number|>

        local function New()
            return setmetatable({Foo = true, Bar = false, Test = 1}, META)
        end

        function META:Test()
            self.tbl = self.tbl or {}
            --attest.equal(self.tbl, _ as {} | List<|number|>)
        end

        function META:Test2()
            if self.tbl then return self.tbl end
            -- this shouldn't cause self.tbl to become nil, although it technically is below the return statement
            -- the contract should allow .tbl to be assigned to List<|number|> or nil
            self.tbl = {}
        end


        local obj = New()
        attest.equal<|obj, {
            Foo = true,
            Bar = false,
            Test = 1,
            tbl = nil, -- TODO?
        }|>
    end

    do
        local META = get_base()
        type META.@SelfArgument.Baz = number

        local function New()
            return setmetatable({Foo = true, Bar = false, Baz = 1}, META)
        end

        local obj = New()
        attest.equal<|obj, {
            Foo = true,
            Bar = false,
            Baz = 1,
        }|>
    end
]]
analyze[[
    local META = {}
    META.Type = "table"
    type META.@SelfArgument = {}
    type META.@SelfArgument.literal_data_cache = META.@SelfArgument
    type META.@Name = "TTable"
    function META.Foo(visited: META.@SelfArgument)
    visited = visited
    end
    local v = {}
    v.literal_data_cache = v
    META.Foo(v)
]]
pending[[
    local list = {}
    list.__index = list
    type list.@SelfArgument = {
        [1..inf] = any,
    }

    function list:insert(val)
        table.insert(self, val)
    end

    function list:remove()
        return table.remove(self)
    end

    function list:move(a: number, b: number, c: number)
        return table.move(self, a, b, c)
    end

    function list:concat(sep: nil | string)
        return table.concat(self, sep)
    end

    function list:sort(comp: nil | function=(any, any)>(boolean))
        table.sort(self, comp)
        return self
    end

    function list:pairs()
        return ipairs(self)
    end

    function list:unpack()
        return table.unpack(self)
    end

    function list:uncalled()
        attest.equal(self[1], _ as nil | any)
    end

    function list:foo()
        return _ as self[number]
    end

    function list.new<|T: any|>(count: nil | number)
        local self = setmetatable({}, list)
        type self[number] = T
        type self.@Contract = self
        return self
    end

    do
        local test = list.new<|number|>()
        attest.expect_diagnostic<|"error", "subset"|>
        test:insert("a")
        do return end
        local val = test[1]
        attest.equal(val, _ as nil | number)
        local val = test:remove()
        attest.equal(val, _ as nil | number)
        local val = test:foo()
        attest.equal(val, _ as nil | number)
    end

    do
        local test = list.new<|string|>()
        list.new<|number|>() -- attempt to confuse 
        test:insert("a")
        local val = test[1]
        attest.equal(val, _ as nil | string)
        local val = test:remove()
        attest.equal(val, _ as nil | string)
        local val = test:foo()
        attest.equal(val, _ as nil | string)
    end
]]
analyze[[
    local meta = {}
    meta.__index = meta
    type meta.@SelfArgument = {foo = number}
    
    local function test(tbl: meta.@SelfArgument & {bar = string | nil})
        attest.equal(tbl.bar, _ as nil | string)
        return tbl:Foo() + 1
    end
    
    function meta:Foo()
        attest.equal<|self.foo, number|>
        return 1336
    end
    
    local obj = setmetatable({
        foo = 1
    }, meta)
    
    attest.equal(obj:Foo(), 1336)
    attest.equal(test(obj), 1337)
]]
analyze[[
    local META = {}
    META.__index = META
    type META.Type = string
    type META.@SelfArgument = {}
    local type BaseType = META.@SelfArgument
    
    function META.GetSet(tbl: ref any, name: ref string, default: ref any)
        tbl[name] = default as NonLiteral<|default|>
    	type tbl.@SelfArgument[name] = tbl[name] 
        tbl["Set" .. name] = function(self: tbl.@SelfArgument, val: typeof tbl[name] )
            self[name] = val
            return self
        end
        tbl["Get" .. name] = function(self: tbl.@SelfArgument): typeof tbl[name] 
            return self[name]
        end
    end
    
    do
        META:GetSet("UniqueID", false as false | number)
        local ref = 0
    
        function META:MakeUnique(b: boolean)
            if b then
                §assert(not env.runtime.self:HasMutations())
                self.UniqueID = ref
                ref = ref + 1
            else
                self.UniqueID = false
            end
    
            return self
        end
    
        function META:DisableUniqueness()
            self.UniqueID = false
        end
    end
]]
analyze[[
    local META = {}
    META.__index = META
    type META.@SelfArgument = {
        Position = number,
        @MetaTable = META,
    }
    local type Lexer = META.@SelfArgument

    function META:IsString()
        return true
    end

    local function ReadCommentEscape(lexer: Lexer & {comment_escape = boolean | nil})
        lexer:IsString()
        lexer.comment_escape = true
    end

    function META:Read()
        ReadCommentEscape(self)
    end
]]
pending[==[

local Vec2 = {}
Vec2.__index = Vec2
type Vec2.@Name = "Vec2"
type Vec2.@SelfArgument = {x = number, y = number, @MetaTable = Vec2}

function Vec2:__tostring()
	return ("Vec2(%f, %f)"):format(self.x, self.y)
end

local function constructor(_, x: number, y: number)
	return setmetatable({x = x, y = y}, Vec2)
end

local op = {
	__add = "+",
	__sub = "-",
	__mul = "*",
	__div = "/",
}

for key, op in pairs(op) do
	local code = [[
        local Vec2 = ...
        function Vec2.]] .. key .. [[(a--[=[#: Vec2.@Self]=], b--[=[#: number | Vec2.@Self]=])
            if type(b) == "number" then
                return Vec2(a.x ]] .. op .. [[ b, a.y ]] .. op .. [[ b)
            end
            return Vec2(a.x ]] .. op .. [[ b.x, a.y ]] .. op .. [[ b.y)
        end
    ]]
	assert(loadstring(code))(Vec2)
end

function Vec2.__eq(a: Vec2, b: Vec2)
	return a.x == b.x and a.y == b.y
end

function Vec2:GetLength()
	return math.sqrt(self.x * self.x + self.y * self.y)
end

Vec2.__len = Vec2.GetLength

function Vec2.GetDot(a: Vec2, b: Vec2)
	return a.x * b.x + a.y * b.y
end

function Vec2:GetNormalized()
	local len = self:GetLength()

	if len == 0 then return Vec2(0, 0) end

	return self / len
end

function Vec2:GetRad()
	return math.atan2(self.x, self.y)
end

function Vec2:Copy()
	return Vec2(self.x, self.y)
end

function Vec2:Floor()
	return Vec2(math.floor(self.x), math.floor(self.y))
end

function Vec2.Lerp(a: Vec2, b: Vec2, t: number)
	return a + (b - a) * t
end

function Vec2:GetRotated(angle: number)
	local self = self:Copy()
	local cs = math.cos(angle)
	local sn = math.sin(angle)
	local xx = self.x * cs - self.y * sn
	local yy = self.x * sn + self.y * cs
	self.x = xx
	self.y = yy
	return self
end

function Vec2:GetReflected(normal: Vec2)
	local proj = self:GetNormalized()
	local dot = proj:GetDot(normal)
	return Vec2(2 * (-dot) * normal.x + proj.x, 2 * (-dot) * normal.y + proj.y) * self:GetLength()
end

setmetatable(Vec2, {__call = constructor})
local v = Vec2(0, 0)
local dot = v:Copy():GetDot(v)
v = v / dot
v = v + Vec2(1, 1) + Vec2(2, 0):GetReflected(Vec2(1, 1)) - v * v * 2
attest.equal(v, Vec2(_ as number, _ as number))


]==]
pending[[
    -- https://github.com/Jacbo1/Public-Starfall/tree/main/Sprite%20Sheet%20Manager
    -- some starfall types
    local type Material = {}
    Material.@Name = "Material"
    type Material.__index = Material
    type Material.setTextureURL = function=(
        Material,
        "$basetexture",
        string,
        nil | function=(any, any, number, number)>(),
        nil | function=()>()
    )>()
    local type material = {}
    type material.create = function=("UnlitGeneric" | "VertexLitGeneric")>(Material)
    local type math = {} & math
    type math.round = function=(number)>(number)
    local type hook = {}
    type hook.add = function=(string, string, function=()>())>()
    local type render = {}
    type render.setMaterial = function=(Material)>()
    type render.drawTexturedRectUV = function=(number, number, number, number, number, number, number, number)>()
    local type timer = {}
    type timer.systime = function=()>(number)
    --@name Sprite sheet Manager
    --@author Jacbo
    local mngr = {}
    mngr.__index = mngr
    type mngr.@SelfArgument = {
        @Name = "Sprite",
        loading = boolean,
        rows = number,
        columns = number,
        mats = List<|Material|>,
        loadings = List<|boolean|>,
        cb = nil | function=(self)>(),
        width = nil | number,
        height = nil | number,
        swidth = nil | number,
        sheight = nil | number,
        @MetaTable = mngr,
    }
    local type Sprite = mngr.@SelfArgument

    -- Creates a sprite sheet manager and loads the image
    function mngr.loadURL(
        url: string,
        columns: number,
        rows: number,
        callback: nil | function=(Sprite)>()
    )
        local mat = material.create("UnlitGeneric")
        local t: Sprite = {
            loading = true,
            rows = rows,
            columns = columns,
            mats = {mat},
            loadings = {true},
            cb = callback,
        }
        setmetatable(t, mngr)

        mat:setTextureURL(
            "$basetexture",
            url,
            function(_, _, width, height)
                t.width = width
                t.height = height
                t.swidth = width / columns
                t.sheight = height / rows
            end,
            function()
                t.loadings[1] = false

                for _, loading in ipairs(t.loadings) do
                    if loading then return end
                end

                t.loading = false

                if t.cb then t.cb(t) end
            end
        )

        return t
    end

    -- Gets the width of a sprite
    function mngr:getSpriteWidth()
        return self.swidth
    end

    -- Gets the height of a sprite
    function mngr:getSpriteHeight()
        return self.sheight
    end

    -- Sets a callback to run when it finishes loading all sprite sheet images
    -- Instantly calls it if it is already loaded
    function mngr:setCallback(callback: function=(Sprite)>())
        self.cb = callback

        if not self.loading then callback(self) end
    end

    -- Appends another piece of the sprite sheet
    function mngr:appendURL(url: string)
        local mat = material.create("UnlitGeneric")
        table.insert(self.mats, mat)
        table.insert(self.loadings, true)
        self.loading = true
        local index = #self.loadings

        mat:setTextureURL(
            "$basetexture",
            url,
            nil,
            function()
                self.loadings[index] = false

                for _, loading in ipairs(self.loadings) do
                    if loading then return end
                end

                self.loading = false
                local cb = self.cb

                if cb then cb(self) end
            end
        )
    end

    -- Draws a sprite in a rectangle
    function mngr:drawSprite(x: number, y: number, width: number, height: number, index: number)
        if not self.loading then
            index = math.round(index)
            local cols, rows, swidth, sheight = self.columns, self.rows, self.swidth as number, self.sheight as number -- indexing self.swidth and self.sheight might return nil
            local sprites = cols * rows
            render.setMaterial(self.mats[math.ceil(index / sprites)] as Material) -- indexing self.mats might return nil
            index = (index - 1) % sprites + 1
            local u = (((index - 1) % cols)) * swidth
            local v = (math.floor((index - 1) / cols)) * sheight
            render.drawTexturedRectUV(
                x,
                y,
                width,
                height,
                u / 1024,
                v / 1024,
                (u + swidth) / 1024,
                (v + sheight) / 1024
            )
        end
    end

    -- Checks if it is loading sprite sheet pieces
    function mngr:isLoading()
        return self.loading
    end

    local manager = mngr
    local delay = 0.05
    local frameCount = 8 ^ 2 * 3
    local sprite_sheet = manager.loadURL(
        "https://cdn.discordapp.com/attachments/607371740540305424/871456722873618442/1.png",
        8,
        8
    )
    sprite_sheet:appendURL(
        "https://cdn.discordapp.com/attachments/607371740540305424/871456756759404584/2.png"
    )
    sprite_sheet:appendURL(
        "https://cdn.discordapp.com/attachments/607371740540305424/871456772580335737/3.png"
    )

    sprite_sheet:setCallback(function(sprite)
        hook.add("render", "", function()
            sprite_sheet:drawSprite(0, 0, 512, 512, math.floor(timer.systime() / delay) % frameCount + 1)
        end)
    end)
]]
pending[==[
    local class = require("nattlua.other.class")

    -- 1. Create templates
    local A_META = class.CreateTemplate("A")
    local B_META = class.CreateTemplate("B")
    local C_META = class.CreateTemplate("C")

    -- 2. Define the union of all our 'type' objects
    --[[# type TAnyObject = A_META.@SelfArgument | B_META.@SelfArgument | C_META.@SelfArgument ]]

    -- 3. Define unique fields
    A_META:GetSet("Value", 0)
    B_META:GetSet("Flag", false)
    C_META:GetSet("Children", {}--[[# as List<|TAnyObject|>]])

    -- 4. Verification function with narrowing
    local function dispatch(obj--[[#: TAnyObject]])
        if obj.Type == "A" then
            -- This should narrow to A_META.@SelfArgument
            attest.equal(obj.Value, _ as number)
        elseif obj.Type == "B" then
            -- This should narrow to B_META.@SelfArgument
            attest.equal(obj.Flag, _ as boolean)
        elseif obj.Type == "C" then
            -- This should narrow to C_META.@SelfArgument
            attest.equal(obj.Children, _ as List<|TAnyObject|>)
        end
    end

    -- 5. Test instances
    local a = A_META.NewObject({Value = 1337})
    local b = B_META.NewObject({Flag = true})
    local c = C_META.NewObject({Children = {a, b}})

    dispatch(a)
    dispatch(b)
    dispatch(c)

]==]
-- maybe this test has nothing to do with metatables?
pending[[
    local META = {}

    function META.GetSet(name: ref string, default: ref any)
        META[name] = default as NonLiteral<|default|>
        local x = function(val: META[name], ...: ...string) 
            attest.equal(val, _ as number) 
            attest.equal<|..., _ as ((string,)*inf,)|> 
        end
    end

    META.GetSet("Data", "1")
    META.GetSet("Data", 1)
    attest.equal(META.Data, _ as number)
]]
pending[[

    local META = {}
    META.__index = META
    META.@SelfArgument = {
        @MetaTable = self,
        @Contract = self,
    }

    function META:at(index: ref number)
        if index < 1 then index = #self.data - -index end

        return self.data[index]
    end

    function META:concat(separator: ref (nil | string))
        return table.concat(self.data, separator)
    end

    function META:every() end

    function META:fill(value: ref any, start: ref (nil | number), stop: ref (nil | number))
        attest.equal<|Widen<|value|>, Widen<|self.data[1]|>, 3|>
        start = start or 1
        stop = stop or #self.data

        for i = start, stop do
            self.data[i] = value
        end
    end

    function META:copy()
        local copy = self:new()

        for i = 1, #self.data do
            copy.data[i] = self.data[i]
        end

        return copy
    end

    function META:new()
        return setmetatable({data = {}}, META)
    end

    function META:filter(
        callback: ref function=(item: ref any, index: ref number, array: ref {[number] = any})>(ref boolean)
    )
        local copy = self:new()

        for i = 1, #self.data do
            if callback(self.data[i], i, self.data) then
                table.insert(copy.data, self.data[i])
            end
        end

        return copy
    end

    local function Array<|T: any, Size: number|>(init: nil | {[Size] = T})
        return setmetatable({data = init or {} as {[Size] = T}}, META)
    end

    local function StaticArray(init: ref {[number] = any})
        return setmetatable({data = init}, META)
    end

    do
        local arr = Array<|string, 1 .. 10|>({"hello", "world"})
        attest.equal<|arr:at(1), string|>
        attest.equal<|arr:at(-9), nil | string|>
        attest.equal<|arr:at(3), nil | string|>
        attest.expect_diagnostic<|"error", "not a subset of"|>
        arr:at(-20)
        attest.equal<|arr:concat(" "), string|>
    end

    do
        local arr = StaticArray({"h", "e", "y"})
        attest.equal(arr:at(1), "h")
        attest.equal(arr:copy(), arr)
        attest.equal(arr:concat("|"), "h|e|y")
        arr:fill("a")
        attest.equal(arr:concat("|"), "a|a|a")
        attest.expect_diagnostic<|"error", "expected string got number"|>
        arr:fill(1)
        -- TODO: don't fill with 1 on error above?
        local arr = StaticArray({"h", "e", "i"})
        local new = arr:filter(function(item, i, arr)
            return item ~= "e"
        end)
        --attest.equal(new:concat(), "hi")
        attest.equal(arr:concat(), "hei")
    end


]]
-- warning, this test freezes
pending[==[
    local Maze = {}
    Maze.__index = Maze

    function Maze:__tostring()
        local out = {}
        table.insert(out, "Maze " .. self.width .. "x" .. self.height .. "\n")

        for y = 0, self.height - 1 do
            for x = 0, self.width - 1 do
                if self:Get(x, y) == 0 then
                    table.insert(out, ".")
                else
                    table.insert(out, "█")
                end
            end

            table.insert(out, "\n")
        end

        return table.concat(out)
    end

    function Maze:Get(x: ref number, y: ref number)
        return self.grid[y * self.width + x]
    end

    function Maze:Set(x: ref number, y: ref number, v: ref (1 | 0))
        self.grid[y * self.width + x] = v
    end

    local function build(self: ref any, x: ref number, y: ref number)
        local r = math.random(0, 3)
        self:Set(x, y, 0)

        for i = 0, 3 do
            local d = (i + r) % 4
            local dx = 0
            local dy = 0

            if d == 0 then
                dx = 1
            elseif d == 1 then
                dx = -1
            elseif d == 2 then
                dy = 1
            else
                dy = -1
            end

            local nx = x + dx
            local ny = y + dy
            local nx2 = nx + dx
            local ny2 = ny + dy

            if self:Get(nx, ny) == 1 then
                if self:Get(nx2, ny2) == 1 then
                    self:Set(nx, ny, 0)
                    build(self, nx2, ny2)
                end
            end
        end
    end

    function Maze:Build(seed: ref number)
        math.randomseed(seed)
        build(self, 2, 2)
        self.grid[self.width + 2] = 0
        self.grid[(self.height - 2) * self.width + self.width - 3] = 0
    end

    local function constructor(_: ref any, width: ref number, height: ref number)
        local self = setmetatable({width = width, height = height, grid = {}}, Maze)

        for y = 0, height - 1 do
            for x = 0, width - 1 do
                self.grid[y * width + x] = 1
            end

            self.grid[y * width + 0] = 0
            self.grid[y * width + width - 1] = 0
        end

        for x = 0, width - 1 do
            self.grid[0 * width + x] = 0
            self.grid[(height - 1) * width + x] = 0
        end

        return self
    end

    setmetatable(Maze, {__call = constructor})

    §analyzer.enable_random_functions = true

    local maze = Maze(13, 13)
    maze:Build(3)
    local str = maze:__tostring()

    if str:find("Maze 13x13", nil, true) == nil then
        error("Maze 13x13 not found")
    end

    if str:find(".█.█████████.", nil, true) == nil then
        error("start of maze not found")
    end

    if str:find(".█████████.█.", nil, true) == nil then
        error("end of maze not found")
    end

    §analyzer.enable_random_functions = false


]==]
