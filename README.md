# About

NattLua is a superset of LuaJIT that adds a structural typesystem. It's built to do accurate analysis with a way to optionally constrain variables.

The entire typesystem itself follows the same philosophy as Lua. You have the freedom to choose how much you want to constrain your program. (🦶🔫!) 

So just like Lua, the typesystem is very flexible, but the analysis is also very accurate.

Complex type structures, such as array-like tables, map-like tables, metatables, and more are supported:

```lua
local list: {[number] = string | nil} = {} -- -1 index is alllowed
local list: {[1..inf] = string | nil} = {} -- only 1..inf index is allowed

local map: {[string] = string | nil} = {} -- any string is allowed
local map: {foo = string, bar = string} = {foo = "hello", bar = "world"} -- only foo and bar is allowed as keys, but they can be any string type

-- note that we add | nil so we can start with an empty table

local a = "fo"
local b = string.char(string.byte("o"))
map[a..b] = "hello" 
--"fo" and "o" are literals and will be treated as such by the type inference
```

```lua
local Vec3 = {}
Vec3.__index = Vec3

-- give the type a friendly name for errors and such
type Vec3.@Name = "Vector"

-- define the type of the first argument in setmetatable
type Vec3.@Self = {
    x = number,
    y = number,
    z = number,
}

function Vec3.__add(a: Vec3, b: Vec3)
    return Vec3(a.x + b.x, a.y + b.y, a.z + b.z)
end

setmetatable(Vec3, {
    __call = function(_, x: number, y: number, z: number)
        return setmetatable({x=x,y=y,z=z}, Vec3)
    end
})

local new_vector = Vector(1,2,3) + Vector(100,100,100)
```

It aims to be compatible with luajit, 5.1, 5.2, 5.3, 5.4 and Garry's Mod Lua (a variant of Lua 5.1).

# Code analysis and typesystem

The analyzer works by evaluating the syntax tree. It runs similar to how Lua runs, but on a more general level and can take take multiple branches if its not sure about if conditions, loops and so on. If everything is known about a program and you did not add any types to generalize you may get its actual output at type-check time.

```lua
local cfg = [[
    name=Lua
    cycle=123
    debug=yes
]]

local function parse(str: literal string)
    local tbl = {}
    for key, val in str:gmatch("(%S-)=(.-)\n") do
        tbl[key] = val
    end
    return tbl
end

local tbl = parse(cfg)
print<|tbl|>
>>
--[[
{
    "name" = "Lua",
    "cycle" = "123",
    "debug" = "yes"
}
]]
```

The literal keyword here means that the `cfg` variable would be passed in as is. It's a bit similar to a generics function. If we instead wrote `: string` the output would be `{ string = string }`

We can also enforce the output type by writing `parse(str: literal string): {[string] = string}`, but if you don't it will be inferred.

When the analyzer detects an error, it will try to recover from the error and continue. For example:

```lua
local obj: nil | (function(): number)
local x = obj()
local y = x + 1
```

This code will report an error about potentially calling a nil value. Internally the analyzer would duplicate the scope, remove nil from the union "obj" so that x contains all the values that are valid in a call operation.

# Current status and goals

My long term goal is to develop a capable language to use for my other projects (such as [goluwa](https://github.com/CapsAdmin/goluwa)).

At the moment I focus strongly on type inference correctness, adding tests and keeping the codebase maintainable.

I'm also in the middle of bootstrapping the project with comment types. So far the lexer part of the project and some other parts are typed and is part of the test suite.

# Types

Fundamentally the typesystem consists of number, string, table, function, symbol, union, tuple and any. Tuples and unions exist only in the typesystem. Symbols are things like true, false, nil, etc.

These types can also be literals, so as a showcase example we can describe the fundamental types like this:

```lua
local type Boolean = true | false
local type Number = -inf .. inf | nan
local type String = $".*"
local type Any = Number | Boolean | String | nil

-- nil cannot be a key in tables
local type Table = { [exclude<|Any, nil|> | self] = Any | self }

-- extend the Any type to also include Any
type Any = Any | Table

local type Function = ( function(...Any): ...Any )

-- note that Function's Any does not include itself. This can be done but it's too complicated as an example
```

So here, `Number` should be semantically mean the same thing as `number`

# Numbers

From narrow to wide

```lua
type N = 1

local foo: N = 1
local foo: N = 2
      ^^^: 2 is not a subset of 1
```

```lua
type N = 1 .. 10

local foo: N = 1
local foo: N = 4
local foo: N = 11
      ^^^: 11 is not a subset of 1 .. 10
```

```lua
type N = 1 .. inf

local foo: N = 1
local bar: N = 2
local faz: N = -1
      ^^^: -1 is not a subset of 1 .. inf
```

```lua
type N = -inf .. inf

local foo: N = 0
local bar: N = 200
local faz: N = -10
local qux: N = 0/0
      ^^^: nan is not a subset of -inf .. inf
```

The logical progression is to define N as `-inf .. inf | nan` but that has semantically the same meaning as `number`

# Strings

Strings can be defined as lua string patterns to constrain them:

```lua
local type MyString = $"FOO_.-"

local a: MyString = "FOO_BAR"
local b: MyString = "lol"
                    ^^^^^ : the pattern failed to match
```

A narrow value:

```lua
type foo = "foo"
```

Or wide:

```lua
type foo = string
```

`$".-"` is semantically the same as `string` but of course internally using `string` would be faster as it avoids string matching all the time

# Tables

are similar to lua tables, where its key and value can be any type.

the only special syntax is `self` which is used for self referencing types

here are some natural ways to define a table:

```lua
local type MyTable = {
    foo = boolean,
    bar = string,
}

local type MyTable = {
    ["foo"] = boolean,
    [number] = string,
}

local type MyTable = {
    ["foo"] = boolean,
    [number] = string,
    faz = {
        [any] = any
    }
}
```

# Unions

A Union is a type separated by `|` these are often used in uncertain conditions.

For example this case:

```lua
local x = 0
-- x is 0 here

if math.random() > 0.5 then
    x = 1
    -- x is 1 here
end

-- x is 1 | 0 here
```

This happens because `math.random()` returns `number` and `number > 0.5` is `true | false`.

```lua
local x = 0
-- x is 0 here
if true then
    x = 1
    -- x is 1 here
end
-- x is still 1 here because the mutation = 1 occured in a certain branch
```

This happens because `true` is true as opposed to `true | false` and so there's no uncertainty of what x is inside the if block or after it.

# Analyzer functions

Analyzer functions are lua functions. We can for example define math.ceil and a print function like this:

```lua
analyzer function print(...)
    print(...)
end

analyzer function math.floor(T: number)
    if T:IsLiteral() then
        return types.Number(math.floor(T:GetData())):SetLiteral(true)
    end

    return types.Number()
end

local x = math.floor(5.5)
print<|x|>
-->> 5
```
When transpiled to lua, the result is just:

The `analyzer` keyword will make the function a lua function. So the code inside that function is actually lua code that is pcall'ed. This is used to define core lua functions like `print` and `math.floor`.

```lua
analyzer function print(...: ...any)
    print(...)
end

print(1,2,3)
-->> 1 2 3
```

This would make it so when you call print at compile time, it actually prints the arguments where the analyzer is currently analyzing.

```lua
local x = math.floor(5.5)
print(x)
```

We can for example define an assertion function like this:

```lua
local function assert_whole_number<|T: number|>
    assert(math.ceil(T) == T, "Expected whole number")
end

local x = assert_whole_number<|5.5|>
          ^^^^^^^^^^^^^^^^^^^: assertion failed!
```

`<|` `|>` here means that we are writing a type function that only exist in the type system. This is different from using `analyzer` keyword because its content is actually analyzed rather than pcall'ed.

When the code above is transpiled to lua, the result is:

```lua
local x = 5.5
```

`<|a,b,c|>` is the way to call type functions. In other languages it tends to be `<a,b,c>` but I chose this syntax to avoid conflicts with the `<` and `>` comparison operators. This may change in the future.

Here's an Exclude function, similar to how you would find in typescript.

```lua
analyzer function Exclude(T, U)
    T:RemoveType(U)
    return T:Copy()
end

local a: Exclude<|1|2|3, 2|>

attest.equal(a, _ as 1|3)
```

It's also possible to the more familiar "generics" syntax

```lua
local function Array<|T: any, L: number|>
    return {[1..L] = T}
end

local list: Array<|number, 3|> = {1, 2, 3, 4}
                                 ^^^^^^^^^^^^: 4 is not a subset of 1..3
```

Note that even though T type annotated with any, it does not mean that T becomes any inside the function. The type annotation here acts more of a constraint. In Typescript it would be something like

```ts
type Array<T extends any, length extends number> = {[key: 1..length]: T} // assuming typescript supports number ranges
```

Type function arguments always need to be explicitly typed.

# More examples

## List type

```lua
function List<|T: any|>
	return {[1..inf] = T | nil}
end

local names: List<|string|> = {} -- the | nil above is required to allow nil values, or an empty table in this case
names[1] = "foo"
names[2] = "bar"
names[-1] = "faz"
^^^^^^^^^: -1 is not a subset of 1 .. inf
```

## ffi.cdef errors in the compiler

```lua
analyzer function ffi.cdef(c_declaration: string)
    -- this requires using analyzer functions

    if c_declaration:IsLiteral() then
        local ffi = require("ffi")
        ffi.cdef(c_declaration:GetData()) -- if this function throws it's propagated up to the compiler as an error
    end
end

ffi.cdef("bad c declaration")
```

```lua
4 | d
5 | end
6 |
8 | ffi.cdef("bad c declaration")
    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
-> | test.lua:8:0 : declaration specifier expected near 'bad'
```

## `load` evaluation

```lua
local function build_summary_function(tbl)
    local lua = {}
    table.insert(lua, "local sum = 0")
    table.insert(lua, "for i = " .. tbl.init .. ", " .. tbl.max .. " do")
    table.insert(lua, tbl.body)
    table.insert(lua, "end")
    table.insert(lua, "return sum")
    return load(table.concat(lua, "\n"), tbl.name)
end

local func = build_summary_function({
    name = "myfunc",
    init = 1,
    max = 10,
    body = "sum = sum + i !!ManuallyInsertedSyntaxError!!"
})
```

```lua
----------------------------------------------------------------------------------------------------
    4 | )
    5 |  table.insert(lua, "end")
    6 |  table.insert(lua, "return sum")
    8 |  return load(table.concat(lua, "\n"))
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    9 | end
10 |
----------------------------------------------------------------------------------------------------
-> | test.lua:8:8
    ----------------------------------------------------------------------------------------------------
    1 | local sum = 0
    2 | for i = 1, 10 do
    3 | sum = sum + i !!ManuallyInsertedSyntaxError!!
                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    4 | end
    5 | return sum
    ----------------------------------------------------------------------------------------------------
    -> | myfunc:3:14 : expected assignment or call expression got ❲symbol❳ (❲!❳)
```

This works because there is no uncertainty about the code generated passed to the load function. If we did `body = "sum = sum + 1" .. (unknown_global as string)`, that would make the table itself become uncertain so that table.concat would return `string` and not the actual results of the concatenation.

## anagram proof
```lua
local bytes = {}
for i,v in ipairs({
    "P", "S", "E", "L", "E",
}) do
    bytes[i] = string.byte(v)
end
local all_letters = _ as bytes[number] ~ nil -- remove nil from the union
local anagram = string.char(all_letters, all_letters, all_letters, all_letters, all_letters)

assert(anagram == "SLEEP")
```

This is true because `anagram` becomes a union of all possible letter combinations which does contain the string SLEEP.

# Parsing and transpiling

I wrote the lexer and parser trying not to look at existing Lua parsers (as a learning experience), but this makes it different in some ways. The syntax errors it can report are not standard and are bit more detailed. It's also written in a way to be easily extendable for new syntax.

- Syntax errors are nicer than standard Lua parsers. Errors are reported with character ranges.
- The lexer and parser can continue after encountering an error, which is useful for editor integration.
- Whitespace can be preserved if needed
- Both single-line C comments (from GLua) and the Lua 5.4 division operator can be used in the same source file.
- Transpiles bitwise operators, integer division, \_ENV, etc down to valid LuaJIT code.

I have not fully decided the syntax for the language and runtime semantics for lua 5.3/4 features. But I feel this is more of a detail that can easily be changed later.

# Development

To run tests run `luajit test/run`

I've setup vscode to run the task `onsave` when a file is saved with the plugin `gruntfuggly.triggertaskonsave`. This runs `on_editor_save.lua` which run tests when modifying the core of the language.

I also have a file called `test_focus.lua` in root which will override the test suite when the file is not empty. This makes it easier for me to debug specific cases.

Some debug features are using the `§` prefix before a statement. This invokes the analyzer so you can inspect the state.
```lua
local x = 1337
§print(env.runtime.x:GetUpvalue())
```

# Similar projects

[Teal](https://github.com/teal-language/tl) is a language similar to this which has a more pragmatic approach. I'm thinking a nice goal is that I can contribute what I've learned here, be it through tests or other things.

[Luau](https://github.com/Roblox/luau) is another project similar to this, but I have not looked so much into it yet.

# Dictionary

I'm not an academic person and so I struggle a bit with naming things properly in the typesystem, but I think I'm getting the hang of it. Here are some definitions, some used in code and some used in my head.

## Type hiearchy

The way I see types is that they are like a parent / children hiearchy. This can be visualized in "mind maps" neatly.

## Subset

If something is "sub" of /lower/inside/contains something larger. For example `1` is a subset of `number` because `number` contains all the numbers.
`1` is also a subset of `1 | 2` since the union contains `1`. But `number` is not a subset of `1` since `1` does not contain numbers like 2, 4, 100, 1337, 90377, etc, only `1`.

```lua
    -- pseduo code

    local one = {1}
    local number = {1,2,3,4,5,6,7,...} -- all possible numbers

    local function is_subset(a, b)
        for _, val in ipairs(a) do
            if not table.contains(val, b) then
                return false, "a is not a subset of b: type b has no field " .. tostring(val)
            end
        end
        return true
    end

    assert(is_subset(one, number))
    assert(not is_subset(number, one))
```

## Superset

The logical opposite of subset

```lua
local is_superset = function(a, b) return is_subset(b, a) end
```

## Literal

Something of which nothing can be a subset of, except itself. It is similar to an atom or unit. This is also called a narrow type.

## `"runtime"` / `"typesystem"`

The analyzer will analyze code in these two different contexts. Locals and environment variables are stored in separate scopes and code behaves a little bit different in each environment. They are like 2 different worlds where the typesystem watches and tells you about how the runtime behaves.

```lua
local a: *type expression analyzed in "typesystem"* = *runtime expression anlyzed in "runtime"*
```

## Contract

If a runtime object has a contract, it cannot be anything that breaks this contract. It's more like a constrain (maybe i should call it constraints!)

```lua
local a: 1 .. 5 = 3 -- 3 is within 1 .. 5 so the contract is not broken
a = 1 -- 1 is still within the contract
a = 6 -- the contract was broken, so throw an error.
```
