local T = require("test.helpers")
local run = T.RunCode



run[[
local   a,b,c = 1,2,3
        d,e,f = 4,5,6

type_assert(a, 1)
type_assert(b, 2)
type_assert(c, 3)

type_assert(d, 4)
type_assert(e, 5)
type_assert(f, 6)

local   vararg_1 = ... as any
        vararg_2 = ... as any

type_assert(vararg_1, _ as any)
type_assert(vararg_2, _ as any)

local function test(...)
    return a,b,c, ...
end

A, B, C, D = test(), 4

type_assert(A, 1)
type_assert(B, 4)
type_assert(C, nil)
type_assert(D, nil)

local z,x,y,æ,ø,å = test(4,5,6)
local novalue

type_assert(z, 1)
type_assert(x, 2)
type_assert(y, 3)
type_assert(æ, 4)
type_assert(ø, 5)
type_assert(å, 6)

A, B, C, D = nil, nil, nil, nil

]]

run([[
    local type Foo = {
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
    ]]:GetLocalOrEnvironmentValue(types.LString("a"), "runtime")

    equal(v:GetData(), 2)

    local v = run[[
        local a = 1
        if true then
            a = 2
        end
    ]]:GetLocalOrEnvironmentValue(types.LString("a"), "runtime")

    equal(v:GetData(), 2)
end)

