local T = require("test.helpers")
local run = T.RunCode


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
        types.assert(test(test(1,2,3), test(1,2,3), test(1,2,3)), 18)
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

        types.assert(a,1)
        types.assert(b,2)
        types.assert(c,3)
    ]]
end)

test("vararg in table", function()
    run[[
        local function test(...)
            local a = {...}
            types.assert(a[1], 1)
            types.assert(a[2], 2)
            types.assert(a[3], 3)
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
        types.assert(a, 10)
        types.assert(b, 20)
        types.assert(c, 30)
    ]]
end)

test("asadawd", function()
    run[[
        local function test(...)
            return 1,2,3, ...
        end

        local A, B, C, D = test(), 4

        types.assert(A, 1)
        types.assert(B, 4)
        types.assert(C, nil)
        types.assert(D, nil)
    ]]
end)

run[[
    local a,b,c = ...
    types.assert(a, _ as any)
    types.assert(b, _ as any)
    types.assert(c, _ as any)
]]
    
run[[
    local tbl = {...}
    types.assert(tbl[1], _ as any)
    types.assert(tbl[2], _ as any)
    types.assert(tbl[100], _ as any)
]]

run[[
    function foo(...)
        local tbl = {...}
        types.assert(tbl[1], _ as any)
        types.assert(tbl[2], _ as any)
        types.assert(tbl[100], _ as any)
    end
]]

run[[
    ;(function(...)   
        local tbl = {...}
        types.assert(tbl[1], 1)
        types.assert(tbl[2], 2)
        types.assert(tbl[100], _ as nil) -- or nil?
    end)(1,2)
]]

run[[
    local a,b,c = unknown()
    types.assert(a, _ as any)
    types.assert(b, _ as any)
    types.assert(c, _ as any)
]]

test("parenthesis around varargs should only return the first value in the tuple", function()
    run[[
        local function s(...) return ... end
        local a,b,c = (s(1, 2, 3))
        types.assert(a, 1)
        types.assert(b, nil)
        types.assert(c, nil)
    ]]
end)

test("analyzer function varargs", function()
    run[[
        local lol = function(...)
            local a,b,c = ...
            types.assert(a, 1)
            types.assert(b, 2)
            types.assert(c, 3)
        end

        local function lol2(...)
            lol(...)
        end

        lol2(1,2,3)
    ]]
end)

run[[
    local type lol = function=()>(...any)

    local a,b,c = lol()

    types.assert(a, _ as any)
    types.assert(b, _ as any)
    types.assert(c, _ as any)    

    local type test = analyzer function(a,b,c) 
        assert(a.Type == "any")
        assert(b.Type == "any")
        assert(c.Type == "any")
    end

    test(lol())
]]

run[[
    local function resume(a, ...)
        local a, b, c = a, ...
        types.assert(a, _ as 1)
        types.assert(b, _ as 2)
        types.assert(c, _ as 3)
    end
    
    resume(1, 2, 3)
]]

run[[
    local type lol = function=()>(1,...any)

    local a,b,c,d = lol()
    types.assert(a, 1)
    types.assert(b, _ as any)
    types.assert(c, _ as any)
    types.assert(d, _ as any)
    
    
    local a,b,c,d = lol(), 2,3,4
    
    types.assert(a,1)
    types.assert(b,2)
    types.assert(c,3)
    types.assert(d,4)
    
    
    local function foo(a, ...)
        local a, b, c = a, ...
        types.assert(a, 1)
        types.assert(b, 2)
        types.assert(c, 3)
    end
    
    foo(1, 2, 3)
    
    local type test = analyzer function(a,b,c,...) 
        assert(a:GetData() == 1)
        assert(b.Type == "any")
        assert(c.Type == "any")
    end
    
    test(lol())
    
    local type test = analyzer function(a,b,c,...)
        assert(a:GetData() == 1)
        assert(b:GetData() == 2)
        assert(c:GetData() == 3)
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
            type_error("wrong")
        end

        return n
    end

    -- test should be executed in the numeric order

    a[test(1)], a[test(2)], a[test(3)] = test(4), test(5), test(6)
]]

run[[
    local t = {foo = true}
    for k,v in pairs(t) do
        types.assert(k, _ as "foo")
        types.assert(v, _ as true)
    end
]]

run[[
    local analyzer function create(func: Function)
        local t = types.Table()
        t.func = func
        return t
    end
    
    local analyzer function call(obj: any, ...: ...any)
        analyzer:Call(obj.func, types.Tuple({...}))
    end
    
    local co = create(function(a,b,c)
        types.assert(a, 1)
        types.assert(b, 2)
        types.assert(c, 3)
    end)
    
    call(co,1,2,3)
]]

run[[
    
    local function foo(...)

        -- make sure var args don't leak onto return type var args

        local type lol = function=()>(...any)
        local a,b,c = lol()
        types.assert(a, _ as any)
        types.assert(b, _ as any)
        types.assert(c, _ as any)
    end
    
    foo(1,2,3)
]]

run[[
    ;(function(...: number) 
        local a,b,c,d = ...
        types.assert(a, _ as number)
        types.assert(b, _ as number)
        types.assert(c, _ as number)
        types.assert(d, nil)
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
    types.assert_superset(foo, nil as function=()>(any))
]]

run[[
    local analyzer function foo(a: any)
        assert(a == nil)
    end

    foo()
]]

run[[
    local analyzer function foo(a: any)
        assert(a.Type == "symbol")
        assert(a:GetData() == nil)
    end

    foo(nil)
]]

do
    _G.LOL = nil
    run[[
        local analyzer function test()
            return function() _G.LOL = true end
        end
        
        -- make sure the tuple is unpacked, otherwise we get "cannot call tuple"
        test()()
    ]]
    assert(_G.LOL == true)
    _G.LOL = nil
end

run[[
    local analyzer function foo() 
        return 1
    end
    
    local a = {
        foo = foo()
    }
    
    §assert(analyzer:GetScope():FindValue(types.LString("a"), "runtime"):GetValue():Get(types.LString("foo")).Type ~= "tuple")
]]

run[[
    local a,b,c = 1,2,3
    local function test(...)
        return a,b,c, ...
    end
    local z,x,y,æ,ø,å = test(4,5,6)

    types.assert(z, 1)
    types.assert(x, 2)
    types.assert(y, 3)
    types.assert(æ, 4)
    types.assert(ø, 5)
    types.assert(å, 6)

]]

run[[
    local function bar(a: string, b: number)
    
    end
    
    local function foo(a: string, ...: ...any)
        bar(a, ...)
    end
    
    foo("hello", {1,2,3})
    foo("hello", "foo")
    foo("hello", 1)
    foo("hello", function() end)
]]