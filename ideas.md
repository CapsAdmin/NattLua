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

this would pass never into my_type_function

should I check for never for all type functions?
```lua
local a = 1
do return end
my_type_function(a)
```

# table expressed as a union of table and array
```lua
local a = {1,2,3, foo = true}
print(a)
>> [1,2,3] | {foo = true}
table.insert(a, 4)
print(a)
>> [1,2,3,4] | {foo = true}
a.foo = nil
>> [1,2,3,4] | {}
print(a)
```

```lua
local a: number[] = {1,2,3}
print(a)
>> [1,2,3]
a.foo = true
^^^^^ error
```


## import export

i like C++'s import export int hat it ignores files

```lua
local mylib {}

...

return mylib
```

to import mylib you need to write 

`import mylib` and not `import "path/to/my_lib.lua"

