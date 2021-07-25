local T = require("test.helpers")
local run = T.RunCode

run[[

    types.assert<|
        Partial<|{
            foo = 1337 | nil,
            bar = 666,
        }|>, 
        {
            foo = 1337 | nil,
            bar = 666 | nil,
        }
    |>

]]

run[[

    types.assert<|
        Required<|{
            foo = 1337 | nil,
            bar = 666,
        }|>, 
        {
            foo = 1337,
            bar = 666,
        }
    |>

]]


run([[

    local tbl = Readonly<|{
        foo = 1337 | nil,
        bar = 666,
    }|>

    tbl.bar = 444

]], "444 is not a subset of 666")


run[[

    local type CatInfo = {
        age = number,
        breed = string,
    }

    local type CatName = "miffy" | "boris" | "mordred"

    local cats = Record<|CatName, CatInfo|> = {
        miffy = { age = 10, breed = "tabby" },
        boris = { age = 20, breed = "shiba" },
        mordred = { age = 30, breed = "sphynx" },
    }

    types.assert(cats.boris.age, _ as number)
]]

run[[

    local type Todo = {
        title = string,
        description = string,
        done = boolean,
    }

    local TodoPreview = Pick<|Todo, "title" | "done"|>

    local todo: TodoPreview = {
        title = "Get a new car",
        done = false,
    }

]]

run([[

    local type Todo = {
        title = string,
        description = string,
        done = boolean,
    }

    local TodoPreview = Omit<|Todo, "done" | "description"|>

    local todo: TodoPreview = {
        title = "Get a new car",
    }

    local todo: TodoPreview = {
        title = "Get a new car",
        done = false,
    }
]], "done")

run[[
    types.assert<|
        Exclude<|1 | 2 | 3, 2|>, 
        1 | 3
    |>
]]

run[[
    types.assert<|
        Extract<|1337 | "deadbeef", number|>, 
        1337
    |>
]]


run[[
    types.assert<|
        Extract<|1337 | 231 | "deadbeef", number|>, 
        1337 | 231
    |>  
]]

run[[
    local function foo(a: number, b: string, c: Table): boolean
        return true
    end

    types.assert<|Parameters<|foo|>[1], number|>
    types.assert<|Parameters<|foo|>[2], string|>
    types.assert<|Parameters<|foo|>[3], Table|>    

    types.assert<|ReturnType<|foo|>[1], boolean|>
]]

run[[
    types.assert<|Uppercase<|"foo"|>, "FOO"|>
    types.assert<|Lowercase<|"FOO"|>, "foo"|>

    -- something is up with chained calls in the typesystem
    --types.assert<|Capitalize<|"foo"|>, "Foo"|>
    --types.assert<|Uncapitalize<|"FOO"|>, "fOO"|>
]]