-- Test 1: Basic @NewMetaTable - self type is inferred from what setmetatable receives
analyze[[
	local META = {}
	META.__index = META
	type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
	type Entity.@NewMetaTable = true

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
	type Player.@NewMetaTable = true
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
	type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
	type META.@Self = {foo = number}

	function META:GetFoo()
		return self.foo
	end

	local obj = setmetatable({foo = 42}, META)
	attest.equal(obj:GetFoo(), _ as number)
]]
-- Test 19: Three-level inheritance (Base -> Mid -> Leaf)
analyze[[
	local Base = {}
	Base.__index = Base
	type Base.@NewMetaTable = true

	function Base.New(id: string)
		return setmetatable({id = id}, Base)
	end

	function Base:GetID(): string
		return self.id
	end

	local Mid = {}
	Mid.__index = Mid
	type Mid.@NewMetaTable = true
	setmetatable(Mid, {__index = Base})

	function Mid.New(id: string, level: number)
		return setmetatable({id = id, level = level}, Mid)
	end

	function Mid:GetLevel(): number
		return self.level
	end

	local Leaf = {}
	Leaf.__index = Leaf
	type Leaf.@NewMetaTable = true
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
	type Base.@NewMetaTable = true

	function Base:Type()
		return "base"
	end

	local Child = {}
	Child.__index = Child
	type Child.@NewMetaTable = true
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
	type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
		type META.@NewMetaTable = true

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
		type META.@NewMetaTable = true

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
		type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
	type META.@NewMetaTable = true

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
		type META.@NewMetaTable = true

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
