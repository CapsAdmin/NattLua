# unreachable and error types?

maybe it will simplify the analyzer

you could analyze a program and collect all error and unreachable types

```lua
local a = nil + 1
print(a)
>> 「error - nil + 1」

local b = a + 2
print(b)
>> 「error - nil + 1」 | 「error - a + 2」

local c = 2
print(c)
>> unreachable | 2
```

```lua
do return end
local a = 1
print(a)
>> unreachable | 1
```

```lua
local a = 1
if false then
    a = 2
    print(a)
    >> 1 | unreachable
end
print(a)
>> 1
```

## problems

we can never prove this

```lua
while not keyboard.IsKeyPressed("space") do 

end

local a = 1
print(a)
>> 1 | unreachable
```

so there should be a way to tell the typesystem about it
maybe something like marking the test condition or scope itself?

```lua
while (_ as any)! do end
```

where `!` means that it will remove any uncertainty. similar to typescript

```lua
local a = (_ as nil | 1)!
print(a)
>> 1
```