local type Vec2 = {x = number, y = number}
local type Vec3 = {z = number} extends Vec2

local type Base = {
    Test = function(self): number,
}

local type Foo = Base extends {
    SetPos = (function(self, pos: Vec3): nil),
}

-- have to use as here because {} would not be a subset of Foo
local x = {} as Foo

x:SetPos({x = 1, y = 2, z = 3})