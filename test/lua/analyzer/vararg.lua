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
        type_assert(tbl[100], _ as nil) -- or nil?
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
    local type lol = (function(): ...)

    local a,b,c = lol()

    type_assert(a, _ as any)
    type_assert(b, _ as any)
    type_assert(c, _ as any)    

    local type test = function(a,b,c) 
        assert(a.Type == "any")
        assert(b.Type == "any")
        assert(c.Type == "any")
    end

    test(lol())
]]

run[[
    local function resume(a, ...)
        local a, b, c = a, ...
        type_assert(a, _ as 1)
        type_assert(b, _ as 2)
        type_assert(c, _ as 3)
    end
    
    resume(1, 2, 3)
]]

run[[
    local type lol = (function(): 1,...)

    local a,b,c,d = lol()
    type_assert(a, 1)
    type_assert(b, _ as any)
    type_assert(c, _ as any)
    type_assert(d, _ as any)
    
    
    local a,b,c,d = lol(), 2,3,4
    
    type_assert(a,1)
    type_assert(b,2)
    type_assert(c,3)
    type_assert(d,4)
    
    
    local function foo(a, ...)
        local a, b, c = a, ...
        type_assert(a, 1)
        type_assert(b, 2)
        type_assert(c, 3)
    end
    
    foo(1, 2, 3)
    
    local type test = function(a,b,c,...) 
        assert(a.data == 1)
        assert(b.Type == "any")
        assert(c.Type == "any")
    end
    
    test(lol())
    
    local type test = function(a,b,c,...)
        assert(a.data == 1)
        assert(b.data == 2)
        assert(c.data == 3)
        assert(... == nil)
    end
    
    test(lol(),2,3)
]]

run[[
    local a = {}

    local i = 0
    local function test(n)
        i = i + 1

        if i ~= n then
            type_error("uh oh")
        end

        return n
    end

    -- test should be executed in the numeric order

    a[test(1)], a[test(2)], a[test(3)] = test(4), test(5), test(6)
]]

run[[
    local t = {foo = true}
    for k,v in pairs(t) do
        type_assert(k, _ as "foo")
        type_assert(v, _ as true)
    end
]]

run[[
    local type function create(func)
        local t = types.Table({})
        t.func = func
        return t
    end
    
    local type function call(obj, ...)
        analyzer:Call(obj.func, types.Tuple({...}))
    end
    
    local co = create(function(a,b,c)
        type_assert(a, 1)
        type_assert(b, 2)
        type_assert(c, 3)
    end)
    
    call(co,1,2,3)
]]

run[[
    
    local function foo(...)

        -- make sure var args don't leak onto return type var args

        local type lol = (function(): ...)
        local a,b,c = lol()
        type_assert(a, _ as any)
        type_assert(b, _ as any)
        type_assert(c, _ as any)
    end
    
    foo(1,2,3)
]]

run[[
    ;(function(...: number) 
        local a,b,c,d = ...
        type_assert(a, 1)
        type_assert(b, 2)
        type_assert(c, 3)
        type_assert(d, nil)
    end)(1,2,3)
]]

run([[
    ;(function(...: number) 
        print("!", ...)
    end)(1,2,"foo",4,5)
]], "foo.-is not the same type as number")

run[[
    local function foo()
        return foo()
    end

    foo()

    -- should not be a nested tuple
    type_assert_superset(foo, nil as (function():any))
]]

run[[
    local type function foo(a)
        assert(a == nil)
    end

    foo()
]]

run[[
    local type function foo(a)
        assert(a.Type == "symbol")
        assert(a.data == nil)
    end

    foo(nil)
]]

do
    _G.LOL = nil
    run[[
        local type function test()
            return function() _G.LOL = true end
        end
        
        -- make sure the tuple is unpacked, otherwise we get "cannot call tuple"
        test()()
    ]]
    assert(_G.LOL == true)
    _G.LOL = nil
end

run[[
    local type function foo() 
        return 1
    end
    
    local a = {
        foo = foo()
    }
    
    §assert(analyzer:GetScope():FindValue("a", "runtime").data:Get("foo").Type ~= "tuple")
]]

run[[
    local a,b,c = 1,2,3
    local function test(...)
        return a,b,c, ...
    end
    local z,x,y,æ,ø,å = test(4,5,6)

    type_assert(z, 1)
    type_assert(x, 2)
    type_assert(y, 3)
    type_assert(æ, 4)
    type_assert(ø, 5)
    type_assert(å, 6)

]]