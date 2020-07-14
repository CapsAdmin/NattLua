local type Base = {
    Test = function(self, number): number,
}

local type Foo = Base extends {
    GetPos = (function(self): number),
}

-- have to use as here because {} would not be a subset of Foo
local x = {} as Foo

type_assert(x:Test(1), _ as number)
type_assert(x:GetPos(), _ as number)