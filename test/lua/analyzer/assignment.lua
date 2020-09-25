local T = require("test.helpers")
local run = T.RunCode

run([[
    type Foo = {
        a = 1,
        b = 2,
    }

    local a: Foo = { a = 1 }    
]], " is missing from ")


run([[
    local type Person = unique {
        id = number,
        name = string,
    }
    
    local type Pet = unique {
        id = number,
        name = string,
    }
    
    local dog: Pet = {
        id = 1,
        name = "pete"
    }
    
    local human: Person = {
        id = 6,
        name = "persinger"
    }
    
    local c: Pet = human    
]], "is not the same unique type as")

test("runtime reassignment", function()
    local v = run[[
        local a = 1
        do
            a = 2
        end
    ]]:GetValue("a", "runtime")

    equal(v:GetData(), 2)

    local v = run[[
        local a = 1
        if true then
            a = 2
        end
    ]]:GetValue("a", "runtime")

    equal(v:GetData(), 2)
end)
