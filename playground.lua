local BASE = {} as {
	A = number,
	B = number,
}

type BASE = typeof BASE & {C = number}

function BASE:Foo(lol: true | false): number
	if lol then
		return "LOL"
	end
	return self.A + self.B
end

local Foo: (typeof BASE) & {__index = self} = {}
Foo.__index = Foo

local self = setmetatable({}, Foo)

print(self:Foo(true))
print(self:Foo())
