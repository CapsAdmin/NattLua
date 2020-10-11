local T = require("test.helpers")
local run = T.RunCode


pending("typed vararg", function()
    local a = run[[
        local foo: string... = 1,2,3
    ]]
    local foo = a:GetEnvironmentValue("foo", "typesystem")
    print(foo)
end)

test("vararg", function()
    run[[
        local function test(...)

        end

        test({})
    ]]
end)

test("vararg", function()
    run[[
        local function test(...)
            local a,b,c = ...
            return a+b+c
        end
        type_assert(test(test(1,2,3), test(1,2,3), test(1,2,3)), 18)
    ]]
end)

test("smoke", function()
    run[[
        local function test()
            return 1,2
        end

        local a,b,c = test(), 3
        assert_type(a, 1)
        assert_type(b, 3)
        assert_type(c, nil)
    ]]

    run[[
        local function test(...)
            return 1,2,...
        end

        local a,b,c = test(3)

        type_assert(a,1)
        type_assert(b,2)
        type_assert(c,3)
    ]]
end)

test("vararg in table", function()
    run[[
        local function test(...)
            local a = {...}
            type_assert(a[1], 1)
            type_assert(a[2], 2)
            type_assert(a[3], 3)
        end

        test(1,2,3)
    ]]
end)

test("var arg in table and return", function()
    run[[
        local a,b,c = test(1,2,3)

        local function test(...)
            local a = {...}
            return a[1], a[2], a[3]
        end

        local a,b,c = test(10,20,30)
        type_assert(a, 10)
        type_assert(b, 20)
        type_assert(c, 30)
    ]]
end)

test("asadawd", function()
    run[[
        local function test(...)
            return 1,2,3, ...
        end

        local A, B, C, D = test(), 4

        type_assert(A, 1)
        type_assert(B, 4)
        type_assert(C, nil)
        type_assert(D, nil)
    ]]
end)

run[[
    local a,b,c = ...
    type_assert(a, _ as any)
    type_assert(b, _ as any)
    type_assert(c, _ as any)
]]
    
run[[
    local tbl = {...}
    type_assert(tbl[1], _ as any)
    type_assert(tbl[2], _ as any)
    type_assert(tbl[100], _ as any)
]]

run[[
    function foo(...)
        local tbl = {...}
        type_assert(tbl[1], _ as any)
        type_assert(tbl[2], _ as any)
        type_assert(tbl[100], _ as any)
    end
]]

run[[
    ;(function(...)   
        local tbl = {...}
        type_assert(tbl[1], 1)
        type_assert(tbl[2], 2)
        type_assert(tbl[100], _ as nil)
    end)(1,2)
]]

run[[
    local a,b,c = unknown()
    type_assert(a, _ as any)
    type_assert(b, _ as any)
    type_assert(c, _ as any)
]]

test("parenthesis around varargs should only return the first value in the tuple", function()
    run[[
        local function s(...) return ... end
        local a,b,c = (s(1, 2, 3))
        type_assert(a, 1)
        type_assert(b, nil)
        type_assert(c, nil)
    ]]
end)

test("type function varargs", function()
    run[[
        local lol = function(...)
            local a,b,c = ...
            type_assert(a, 1)
            type_assert(b, 2)
            type_assert(c, 3)
        end

        local function lol2(...)
            lol(...)
        end

        lol2(1,2,3)
    ]]
end)

run[[
    type lol = (function(): ...)

    local a,b,c = lol()

    type_assert(a, _ as any)
    type_assert(b, _ as any)
    type_assert(c, _ as any)    

    type test = function(a,b,c) 
        assert(a.Type == "any")
        assert(b.Type == "any")
        assert(c.Type == "any")
    end

    test(lol())

    type test = function(a,b,c) 
        assert(a.Type == "tuple")
        assert(b == nil)
        assert(c == nil)
    end

    test<|lol()|>
]]