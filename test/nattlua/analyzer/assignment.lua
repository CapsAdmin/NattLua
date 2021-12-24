local T = require("test.helpers")
local run = T.RunCode
local String = T.String


run[[
local   a,b,c = 1,2,3
        d,e,f = 4,5,6

types.assert(a, 1)
types.assert(b, 2)
types.assert(c, 3)

types.assert(d, 4)
types.assert(e, 5)
types.assert(f, 6)

local   vararg_1 = ... as any
        vararg_2 = ... as any

types.assert(vararg_1, _ as any)
types.assert(vararg_2, _ as any)

local function test(...)
    return a,b,c, ...
end

A, B, C, D = test(), 4

types.assert(A, 1)
types.assert(B, 4)
types.assert(C, nil)
types.assert(D, nil)

local z,x,y,æ,ø,å = test(4,5,6)
local novalue

types.assert(z, 1)
types.assert(x, 2)
types.assert(y, 3)
types.assert(æ, 4)
types.assert(ø, 5)
types.assert(å, 6)

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
    ]]:GetLocalOrEnvironmentValue(String("a"))

    equal(v:GetData(), 2)

    local v = run[[
        local a = 1
        if true then
            a = 2
        end
    ]]:GetLocalOrEnvironmentValue(String("a"))

    equal(v:GetData(), 2)
end)

