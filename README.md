# About

NattLua is variant of LuaJIT with optional types. The main goal is to provide a complete picture of how a program might run or fail in all possible paths. 

Tooling consists of a cli and an lsp for vscode. There is also a [playground](https://capsadmin.github.io/NattLua/) you can try. It supports hover type information and other diagnostics.

Here are some examples:

```lua
local x = 1 -- 1
x = x + 1 -- 2, addition works

local x: number = 1 -- number
x = x + 1 -- x is still number

local a = "fo" -- "fo"

-- these are type functions that operate on both literal and non literal types
local b = string.char(string.byte("o")) 

local map = {}
map[a..b] = "hello" -- map is now {foo = "hello"}
```
```lua
-- index -1 alllowed
local list: {[number] = string | nil} = {}

-- same as the above, but expressed differently
local list: {[number] = string} | {} = {}

-- only index 1..inf allowed
local list: {[1..inf] = string | nil} = {}

-- string index allowed
local map: {[string] = string | nil} = {}

-- only foo and bar are allowed as keys, but values can be string
local map: {foo = string, bar = string} = {foo = "hello", bar = "world"} 

local type MyTable = {
    foo = boolean,
    bar = string,
}

-- mutating types is allowed, just like you'd expect in Lua
type MyTable.faz = number
```
```lua
local Vec3 = {}
Vec3.__index = Vec3

-- give the type a friendly name for editor tooling
type Vec3.@Name = "Vector"

-- define the type of the first argument in setmetatable
type Vec3.@SelfArgument = {
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

local new_vector = Vector(1,2,3) + Vector(100,100,100) -- OK
```
```lua
-- this print call is a typesystem call
-- this will be ommitted when transpiling back to LuaJIT
print<|{foo = "hello"}|> 
-- this would print '{foo = "hello"}' if you were to run "nattlua check myfile.nlua"
```
# Types

Fundamentally the typesystem consists of number, string, table, function, symbol, range, union, tuple and any. Tuples and unions and ranges exist only in the typesystem. Symbols are things like true, false, nil, etc.

Most types can go from wide > narrow > literal. As a demo we can describe the fundamental types like this:

```lua
local type Boolean = true | false
local type Number = -inf..inf | nan
local type String = $".*"
local type AnyValue = Number | Boolean | String | nil

-- nil and nan cannot be used as a key in tables
-- self means the current table type, useful for recursive type declarations
local type Table = { [AnyValue ~ (nan | nil) | self] = AnyValue | self }

local type AnyValueWithTable = AnyValue | Table

-- CurrentType is a type function that lets us get the reference to the current type we're constructing
local type Function = function=(...AnyValueWithTable | CurrentType<|"function"|>)>(...AnyValueWithTable | CurrentType<|"function"|>)

-- declare the global type
type Any = AnyValueWithTable | Function
```

So here all the PascalCase types should have semantically the same meaning as their lowercase counter parts.

# Numbers and ranges

From literal > narrow > wide

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

The logical progression would be defining N as `-inf .. inf | nan` but that has semantically the same meaning as `number`

# Strings

Strings can be defined more narrowly as lua string patterns:

```lua
local type MyString = $"FOO_.-"

local a: MyString = "FOO_BAR"
local b: MyString = "lol"
                    ^^^^^ : the pattern failed to match
```

A literal value:

```lua
type foo = "foo"
```

Or wide:

```lua
type foo = string
```

`$".-"` is semantically the same as `string`

# Tables

Tables are similar to lua tables, where its key (except nan and nil) and value can be of any type.

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

-- extend the type
type MyTable.bar = number
```

# Unions

A Union is a collection of types separated by `|` These tend to show up in uncertain conditions.

For example this case:

```lua
local x = 0
-- x is 0 here

if math.random() > 0.5 then
    -- x is 0 here
    x = 1
    -- x is 1 here
else
    -- x is 0 here
    x = 2
    -- x is 2 here
end

-- x is 1 | 2 here
```

This happens because `math.random()` returns `number` and `number > 0.5` is `true | false`.

One of these if blocks must execute; that's why we end up with `1 | 2` instead of `0 | 1 | 2`.

```lua
local x = 0
-- x is 0 here
if true then
    x = 1
    -- x is 1 here
end
-- x is still 1 here because the mutation = 1 occured in a certain branch
-- we would also get a warning saying the branch is always truthy
```

This happens because `true` is true as opposed to `true | false` and so there's no uncertainty in executing the if block.

# Control flow

The analyzer works by evaluating the syntax tree. It runs similar to how Lua runs, but on a more general level, and can take take multiple paths when "if" conditions and loops are uncertain. If everything is known about a program, and you didn't widen any types, you may get the actual output during analysis.

Types must be declared in the right order. You cannot declare a type at the bottom of a script and use it at the top. This follows the same rules as Lua.

In languages like Typescript, types are purely functional, but in Nattlua types are written as Lua is written, though different operators and behavior apply.

# Type functions

Type functions is the recommended way to write type functions. We can define an assertion function like this:

```lua
local function assert_whole_number<|T: number|>
    assert(math.floor(T) == T, "expected integer, got decimal")
end

local x = assert_whole_number<|5.5|>
          ^^^^^^^^^^^^^^^^^^^
expected integer, got decimal
```

`<|` `|>` here means that we are writing a type function that only exist in the type system. Unlike `analyzer` functions, its content is actually analyzed.

When the code above is transpiled to lua, the result is just:

```lua
local x = 5.5
```

`<|a,b,c|>` is the way to call type functions. In other languages it tends to be `<a,b,c>` but I chose this syntax to avoid conflicts with the `<` and `>` comparison operators. This syntax may change in the future.

```lua
local function Array<|T: any, L: number|>
    return {[1..L] = T}
end

local list: Array<|number, 3|> = {1, 2, 3, 4}
                                 ^^^^^^^^^^^^: 4 is not a subset of 1..3
```

In type functions, the type is by default passed by reference. So `T: any` does not mean that T will be any in the function body. It just means that the argument T is allowed to be any.

In Typescript it would be something like

```ts
type Array<T extends any, length extends number> = {[key: 1..length]: T} 
// assuming typescript supports number ranges
```

Type function arguments always need to be explicitly typed.

### Required function example


```lua
local function Required<|tbl: Table|>
	local copy = {}

    -- go over each key value pair in the type
	for key, val in pairs(tbl) do
		copy[key] = val ~ nil -- because val is a union, we remove nil from it
	end

	return copy
end

local type Props = {
	a = nil | number,
	b = nil | string,
}
-- ok
local obj: Props = {a = 5}

-- error!
local obj2: Required<|Props|> = {a = 5}
```
```lua
 16 | local obj2: Required<|Props|> = {a = 5}
            ^^^^^^^^^^^^^^^^^^^^^^^
 -> | { ["a"] = number } has no key "b"
```
This is  a natural way

# Analyzer functions

Analyzer functions help bind advanced type functions to the analyzer. We can for example define math.ceil and a print function like this:

```lua
analyzer function print(...)
    print(...)
end

analyzer function math.floor(T: number)
    if T:IsLiteral() then
        return types.Number(math.floor(T:GetData()))
    end

    return types.Number()
end

local x = math.floor(5.5)
print<|x|>
-->> 5
```

When transpiled to Lua:

```lua
local x = math.floor(5.5)
```

So analyzer functions only exist when analyzing. The body of these functions are not analyzed like the rest of the code. For example, if this project was written in Python, the contents of the analyzer functions would probably be written in Python leveraging compile() as well.

They exist to provide a way to define advanced custom types and functions that cannot easily be made into a normal type function.
## ffi.cdef parse errors to type errors

In NattLua, ffi type definitions are mostly complete. There is a c declaration parser and type definitions for ctype and cdata, 
but to showcase a useful example of analyzer functions, here's a minimal ffi.def type definition:

```lua
type ffi = {}
analyzer function ffi.cdef(c_declaration: string)
    if c_declaration:IsLiteral() then
        local ffi = require("ffi")
        ffi.cdef(c_declaration:GetData()) -- if cdef throws an error, it's propagated up to the compiler as an error
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
However this is not ideal, because we'd run into redeclaration errors and whatnot in practice.
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

This works because there is no uncertainty about the code generated passed to the load function. If we wrote `body = "sum = sum + 1" as string`, it would widen the body value in the table so, which in turn would cause table.concat return `string` and not the actual results of the concatenation.
## ref keyword

```lua
local cfg = [[
    name=Lua
    cycle=123
    debug=yes
]]

local function parse(str: ref string)
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

The `ref` keyword means that the `cfg` variable would be passed in as is to the parse function's `str` argument, as opposed to getting widened to string. 
This is similar to how type arguments in a generic function is passed to the function itself. If we removed the `ref` keyword, the output of the function is be inferred to be `{ [string] = string }` because `str` would become a non literal string.

We can also add a return type to `parse` by writing `function parse(str: ref string): {[string] = string}` to help constrain the output, but if you don't it will be inferred. The `ref` keyword is also supported on the return type so that you may get the literal output, serving as a typical generic function.

## errors

```lua
local func = nil
if math.random() > 0.5 then func = function() return 1336 end end
-- func is now the type: nil | function=()>(1336)
local x = func() -- error calling a nil value, but the value is 1336
local y = x + 1 -- y is 1337
```

When the analyzer reports an error in this case, it would would branch out, creating a scope where nil is removed from the union `nil | (function(): 1336)` after the call and continue.


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

print<|anagram|> -- >> "EEEEE" | "EEEEL" | "EEEEP" | "EEEES" | "EEELE" | "EEELL" | ...
assert(anagram == "SLEEP")
print<|anagram|> -- >> "SLEEP"
```

This is true because `anagram` becomes a union of all possible letter combinations which also contains the string "SLEEP".

However, it's also false as it contains all the other combinations, but since we use assert to check the result at runtime, it will silently "error" and mutate the anagram upvalue to become "SLEEP" after the assertion.

If we did assert<|anagram == "SLEEP"|> (a type call) it would error, because the typesystem operates more literally, and so a literal string type is not the same as a union of literal strings. The equivalent in the typesystem would be the subset operator, so `assert<|"SLEEP" subsetof anagram|>`

# Parsing and transpiling

As a learning experience I wrote the lexer and parser trying not to look at existing Lua parsers, but this makes it different in some ways. The syntax errors it can report are not standard and are bit more detailed. It's also written in a way to be easily extendable for new syntax.

- Syntax errors can be nicer than standard Lua parsers. Errors are reported with character ranges.
- The lexer and parser can continue after encountering an error, which is useful for editor integration.
- Whitespace can be preserved if needed
- Both single-line C comments (from GLua) and the Lua 5.4 division operator can be used in the same source file.
- Transpiles bitwise operators, integer division, \_ENV, etc down to valid LuaJIT code.
- Supports inline importing via import, require, loadfile, and dofile.
- Supports teal syntax, however the analyser does not currently support its global scoping rules.

I have not fully decided the syntax for the language and runtime semantics for lua 5.3/4 features. But I feel this is more of a detail that can easily be changed later.

# Current status and goals

My long term goal is to develop a language to use for my other projects (such as [goluwa](https://github.com/CapsAdmin/goluwa)).

At the moment I focus strongly on type inference correctness, adding tests and keeping the codebase maintainable.

I'm also working on bootstrapping the project with comment types. So far the lexer part of the project and some other parts are typed and is part of the test suite.

It aims to be compatible with LuaJIT as a frst class citizen, but also 5.1, 5.2, 5.3, 5.4 and Garry's Mod Lua (a variant of Lua 5.1).

# Development

To run tests run `luajit nattlua.lua test`

To build run `luajit nattlua.lua build`

To format the codebase with NattLua run `luajit nattlua.lua fmt`

To build vscode extension run `luajit nattlua.lua build-vscode`

To install run `luajit nattlua.lua install`

If you install you'd get the binary `nattlua` which behaves the same as `luajit nattlua.lua ...`

I've setup vscode to run the task `onsave` when a file is saved with the plugin `pucelle.run-on-save`. This runs `on_editor_save.lua` which has some logic to choose which files to run when modifying project.

There is also some hotreload comment syntax which can let you specify which tests to run when saving a file, along with hotreload.lua scripts that specify how any file in the directory and sub directories will be ran when saved.

I also locally have a file called `test_focus.nlua` in root which will override hotreload logic when the file is not empty. This makes it easier to debug specific tests and code.

Some debug language features are:

`§` followed by lua code. This invokes the analyzer so you can inspect or modify its state.

```lua
local x = 1337
§print(env.runtime.x:GetUpvalue())
§print(analyzer:GetScope())
```

`£` followed by lua code. This invokes the parser so you can inspect or modify its state.

```lua
local x = 1337
£print(parser.current_statement)
```

# Similar projects

[Teal](https://github.com/teal-language/tl) has a more pragmatic and stricter approach when it comes to type inference.

[Luau](https://github.com/Roblox/luau) Similar to teal, but closer to typescript in syntax for types.

[sumneko lua](https://github.com/sumneko/lua-language-server) a language server for lua that supports analyzing lua code. It has a typesystem that can be controlled by using comments.

[EmmyLua](https://github.com/EmmyLua/VSCode-EmmyLua) Similar to sumneko lua.
