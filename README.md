# what this is
This is a Lua based language that transpiles to Lua. It's mostly just a toy project and place for me to explore how programming languages are built.

I see this project as 5 parts at the moment. The lexer, parser, analyzer and emitter. And the typesystem which tries to exist separate from the analyzer.

# lexer and parser
I wrote the lexer and lua parser trying not to look at existing lua parsers as a learning experience. The syntax errors it can produce are more verbose than the original lua parser and it differentiates between some cases. Whitespace (which i define as whitespace and comments) are also preserved properly.

# analyzer and typesystem
The analyzer will execute the syntax tree by walking through it. I believe it works similar to how the lua vm works. Every branch of an if statement is executed unless it's known for sure to be false, a `for i = 1, 10 do` loop would be run once where i is a number type with a range from 1 to 10.

# emitter
This part is a bit boring, it just emits lua code from the syntax tree. The analyzer can also annotate the syntax tree so you can see the output with types.

# status
I focus strongly on correctness at the moment and not performance. I tend to refactor code in one swoop and after I get tests working. I'm mostly driven by curiosity and challenges with designing the typesystem.

# types

Fundementally the typesystem consists of number, string, table, function, symbol, set, tuple and any. These types can be literal

All the basic lua types could be defined as following to give an idea of how the typesystem works.

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

if math.random() > 0.5 then
    x = 1
end
```

The analyzer will say that x is `1 | 0` (1 or 0) 

This happens because `math.random()` returns `number` and `number > 0.5` is `true | false`. So when x is assigned in an uncertain scope it will become a set of its old value and its new value.

```lua
local x = 0

if true then
    x = 1
end
```

In this case however x is 0 before the if statement and 1 after. Mutation is allowed because we didn't define what x should be. 

If we add a type annotation `local x: 0 = 0` it will error inside the if statement.

# other examples

we can for example define a list type:

```lua
type StringList = { [1 .. inf] = string}

local names: StringList = {}
names[1] = "foo"
names[2] = "bar"
names[-1] = "faz"
^^^^^^^^^: -1 is not a subset of 1 .. inf
```

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
    T:RemoveElement(U)
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

# development

To run tests run `luajit test/run`

I've setup vscode to run the task `onsave` when a file is saved with the plugin `gruntfuggly.triggertaskonsave`. This runs `on_editor_save.lua` which run tests when modifying the core of the language.

I also have a file called `test_focus.lua` in root which will override the test suite when the file is not empty. This makes it easier for me to debug specific cases.

# similar projects

Teal (https://github.com/teal-language/tl) is a language similar to this, with a much higher likelyhood of succeeding as it does not intend to be as verbose as this project. I'm thinking another nice goal is that I can contribute what I've learned here.
