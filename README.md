# what this is
This is a Lua based language that transpiles to Lua. It's mostly just a toy project and place for me to explore how programming languages are built.

I see this project as 5 parts at the moment. The lexer, parser, analyzer and emitter. And the typesystem which tries to exist separate from the analyzer.

# lexer and parser
I wrote the lexer and lua parser trying not to look at existing lua parsers as a learning experience. The syntax errors it can produce are more verbose than the original lua parser and it differentiates between some cases. Whitespace is also preserved properly.

# analyzer and typesystem
The analyzer works by walking through the syntax tree node by node. It runs similar to how lua runs, but on a more general level. If everything is known about a program you may get the actual output.

# emitter
The emitter is a bit boring, it just emits lua code from the syntax tree. The analyzer can also annotate the syntax tree so that you can see the output with types.

# current goals
I focus strongly on correctness and making things general and low-level. 

For instance, I prefer `boolean` to be a set of 2 unique symbols `true` and `false` rather than its own type.

# types

Fundementally the typesystem consists of number, string, table, function, symbol, set, tuple and any. They can be described by the typesystem like this:

```lua
type boolean = true | false
type number = -inf .. inf | nan
type string = $".-"
type table = {[number | boolean | string | self] = number | boolean | string | nil | self}
type any = number | boolean | string | nil | table
```

# numbers 
can be ranged:

```lua
type N = 1 .. inf

local foo: N = 1
local bar: N = 2
local faz: N = -1
      ^^^: -1 is not a subset of 1 .. inf
```

a literal value:
```lua
type one = 1
```

or loose:
```lua
type one = number
```

`-inf .. inf | nan` is semantically the same as `number`

# strings
can be defined as lua string patterns to constrain them:

```lua
local type mystring = $"FOO_.-"

local a: mystring = "FOO_BAR"
local b: mystring = "lol"
                    ^^^^^ : the pattern failed to match
```
a literal value:
```lua
type foo = "foo"
```

or loose:
```lua
type one = string
```

`$".-"` is semantically the same as `string` but internally using `string` would be faster as it avoids string matching all the time

# tables 
are similar to lua tables, where its key and value can be any type. 

the only special syntax is `self` which is used for self referencing types

here are some natural ways to define a table:

```lua
local type mytable = {
    foo = boolean,
    bar = string,
}

local type mytable = {
    ["foo"] = boolean,
    [number] = string,
}

local type mytable = {
    ["foo"] = boolean,
    [number] = string,
    faz = {
        [any] = any
    }
}
```

# sets
are types separated by `|` these are mostly used in uncertain conditions.

for example this case:

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
-- x is still 1 here
```
This happens because there's no doubt that `true` is true and so there's no uncertainty of what x is inside the if block or after it.

# type functions
Type functions are lua functions. We can for example define math.ceil and a print function like this:

```lua
type function print(...)
    print(...)
end

type function math.floor(T: number)
    if T:IsLiteral() then
        return types.Number(math.floor(T:GetData())):MakeLiteral(true)
    end

    return types.Number()
end

local x = math.floor(5.5)
print(x)
```

When this code is analyzed, it will print 5 in its output. 
When transpiled to lua, the result is:
```lua
local x = math.floor(5.5)
print(x)
```

We can also define an assertion like this:

```lua
type function assert_whole_number(T: number)
    assert(math.ceil(T:GetData()) == T:GetData())
end

local x = assert_whole_number<|5.5|>
          ^^^^^^^^^^^^^^^^^^^: assertion failed!
```

But when this code is transpiled to lua, the result is:
```lua
local x = 5.5
```

`<|a,b,c|>` is the way to call type functions. In other languages it tends to be `<a,b,c>` but I chose this syntax to avoid conflicts with the `<` and `>` comparison operators


Here's an Exclude function, similar to how you would find in typescript.

```lua
type function Exclude(T, U)
    T:RemoveType(U)
    return T
end

local a: Exclude<|1|2|3, 2|>

type_assert(a, _ as 1|3)
```

It's also possible to use a more familiar "generics" syntax

```lua
local function Array<|T: any, L: number|>
    return {[1 .. L] = T}
end

local list: Array<|number, 3|> = {1, 2, 3, 4}
                                 ^^^^^^^^^^^^: 4 is not a subset of 1..3
```

Note that even though T type annotated with any, it does not mean that T becomes any inside the function. The type annotation here acts more of a constraint. In Typescript it would be something like

```ts
type Array<T extends any, length extends number> = {[key: 1 .. length]: T}
```
(assuming typescript supports number ranges)

Type function arguments needs to be explicitly typed.

# examples

## list type

```lua
type StringList = { [1 .. inf] = string}

local names: StringList = {}
names[1] = "foo"
names[2] = "bar"
names[-1] = "faz"
^^^^^^^^^: -1 is not a subset of 1 .. inf
```

## ffi.cdef errors in the compiler
```lua
type function ffi.cdef(c_declaration: string)
    if c_declaration:IsLiteral() then
        local ffi = require("ffi")
        ffi.cdef(c_declaration:GetData())
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
                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        4 | end
        5 | return sum
        ----------------------------------------------------------------------------------------------------
        -> | myfunc:3:14 : expected assignment or call expression got ❲symbol❳ (❲!❳)
```
This works because there is no uncertainty about the code generated passed to the load function. If there was, lets say we did `body = "sum = sum + 1" .. (unknown_global as string)`, this would make the table itself become uncertain so that table.concat would return `string` and not the actual results of the concatenation.

# development

To run tests run `luajit test/run`

I've setup vscode to run the task `onsave` when a file is saved with the plugin `gruntfuggly.triggertaskonsave`. This runs `on_editor_save.lua` which run tests when modifying the core of the language.

I also have a file called `test_focus.lua` in root which will override the test suite when the file is not empty. This makes it easier for me to debug specific cases.

# similar projects

Teal (https://github.com/teal-language/tl) is a language similar to this, with a much higher likelyhood of succeeding as it does not intend to be as verbose as this project. I'm thinking another nice goal is that I can contribute what I've learned here.
