local T = require("test.helpers")
local run = T.RunCode

test("order of 'and' expression", function()
    run[[
        local res = 0
        local a = function(arg) 
            if res == 0 then
                type_assert(arg, 1)
            elseif res == 1 then
                type_assert(arg, 2)
            end
            res = arg
            return true 
        end
        local b = a(1) and a(2)
    ]]
end)

test("if left side is false or something, return a set of the left and right side", function()
    run[[
        local a: false | {foo = true}
        local b = a and a.foo
        type_assert(b, _ as false | true)
    ]]
end)

test("if left side of 'and' is false, don't analyze the right side", function()
    run[[
        local a = function(arg) 
            type_assert(arg, 1)
            return false
        end

        local b = a(1) and a(2)
    ]]
end)

test("if left side of 'or' is true, don't analyze the right side", function()
    run[[
        local a = function(arg) 
            type_assert(arg, 1)
            return 1337
        end
        
        local b = a(1) or a(2)
        type_assert(b, 1337)
    ]]
end)

test("right side of or", function()
    run[[
        local a = function(arg) 
            if arg == 1 then return false end
            return 1337
        end
        
        local b = a(1) or a(2)
        type_assert(b, 1337)
    ]]
end)

test("orrr", function()
    run[[
        local maybe: false | true
        local b = maybe or 1
        type_assert(b, _ as true | 1)
    ]]

    run[[
        local maybe: false | true
        local b = maybe or maybe
        type_assert(b, _ as true | false)
    ]]

    run[[
        local maybe: false | true
        local maybe2: nil | 1337
        local b = maybe or maybe2
        type_assert(b, _ as 1337 | nil | true)
    ]]

    run[[
        local maybe: false | true
        local maybe2: nil | 1337
        local b = maybe2 or maybe
        type_assert(b, _ as 1337 | false | true)
    ]]
end)