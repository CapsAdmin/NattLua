local T = require("test.helpers")
local run = T.RunCode

test("should return a tuple with types", function()
    local analyzer = run([[
        local type test = function()
            return 1,2,3
        end

        local type a,b,c = test()
    ]])

    equal(1, analyzer:GetLocalOrEnvironmentValue("a", "typesystem"):GetData())
    equal(2, analyzer:GetLocalOrEnvironmentValue("b", "typesystem"):GetData())
    equal(3, analyzer:GetLocalOrEnvironmentValue("c", "typesystem"):GetData())
end)

test("should be able to error", function()
    run([[
        local type test = function()
            error("test")
        end

        test()
    ]], "test")
end)

test("exclude type function", function()
    run([[
        local type function Exclude(T, U)
            T:RemoveType(U)
            return T
        end

        local a: Exclude<|1|2|3, 2|>

        type_assert(a, _ as 1|3)
    ]])

    run([[
        local type function Exclude(T, U)
            T:RemoveType(U)
            return T
        end

        local a: Exclude<|1|2|3, 2|>

        type_assert(a, _ as 11|31)
    ]], "expected 11 | 31 got 1 | 3")
end)

test("self referenced type tables", function()
    run[[
        local type a = {
            b = self,
        }
        type_assert(a, a.b)
    ]]
end)

test("next", function()
    run[[
        local t = {k = 1}
        local a = 1
        local k,v = next({k = 1})
        type_assert(k, nil as "k" | "k")
        type_assert(v, nil as 1 | 1)
    ]]
    run[[
        local k,v = next({foo = 1})
        type_assert(string.len(k), _ as 3 | 3)
        type_assert(v, _ as 1 | 1)
    ]]
end)

test("math.floor", function()
    run[[
        type_assert(math.floor(1.5), 1)
    ]]
end)

test("assert", function()
    run([[
        type_assert_truthy(1 == 2, "lol")
    ]],"lol")
end)

do
    _G.TEST_DISABLE_ERROR_PRINT = true
    test("require should error when not finding a module", function()
        local a = run([[require("adawdawddwaldwadwadawol")]])
        assert(a:GetDiagnostics()[1].msg:find("unable to find module"))
    end)
    _G.TEST_DISABLE_ERROR_PRINT = false
end

test("rawset rawget", function()
    run[[
        local meta = {}
        meta.__index = meta

        local called = false
        function meta:__newindex(key: string, val: any)
            called = true
        end

        local self = setmetatable({}, meta)
        rawset(self, "lol", "LOL")
        type_assert(rawget(self, "lol"), "LOL")
        type_assert(called, false)
    ]]
end)

test("select", function()
    run[[
        type_assert(select("#", 1,2,3), 3)
    ]]
end)

test("parenthesis around vararg", function()
    run[[
        local a = select(2, 1,2,3)
        type_assert(a, 2)
        type_assert((select(2, 1,2,3)), 2)
    ]]
end)

test("varargs", function()
    run[[
    local type test = function(...) end
    local a = {}
    a[1] = true
    a[2] = false
    test(test(a))

    ]]
end)

test("exlcude", function()
    run[[
        local type function Exclude(T, U)
            T:RemoveType(U)
            return T
        end

        local a: Exclude<|1|2|3, 2|>
        type_assert(a, _ as 1|3)
    ]]
end)

test("table.insert", function()
    run[[
        local a = {}
        a[1] = true
        a[2] = false
        table.insert(a, 1337)
        type_assert(a[3], 1337)
    ]]
end)

test("string sub on union", function()
    run[[
        local lol: "foo" | "bar"

        type_assert(lol:sub(1,1), _ as "f" | "b")
        type_assert(lol:sub(_ as 2 | 3), _ as "ar" | "o" | "oo" | "r")
    ]]
end)

do 
    _G.test_var = 0
    run[[
        
        local type function test(foo: number)
            -- when defined as number the function should be called twice for each number in the union
            
            _G.test_var = _G.test_var + 1
        end
        
        test(_ as 1 | 2)
    ]]
    assert(_G.test_var == 2)

    _G.test_var = 0
    run[[
        
        local type function test(foo: any)
            -- when defined as anything, or no type it should just pass the union directly

            _G.test_var = _G.test_var + 1
        end
        
        test(_ as 1 | 2)
    ]]
    assert(_G.test_var == 1)

    _G.test_var = 0
    run[[
        
        local type function test(foo: number | nil)
            -- if the only type added to the union is nil it should still be called twice
            _G.test_var = _G.test_var + 1
        end
        
        test(_ as 1 | 2)
    ]]
    assert(_G.test_var == 2)

    _G.test_var = nil
end

run[[
    local ok, err = type_pcall(function()
        type_assert(1, 2)
        return 1
    end)

    type_assert(ok, false)
    type_assert_superset(err, _ as string)

    local ok, val = type_pcall(function() return 1 end)
    
    type_assert(ok, true)
    type_assert(val, 1)
]]

run([[
    local type function Exclude(T, U)
        T:RemoveType(U)
        return T
    end

    local a: Exclude<|1|2|3, 2|>

    type_assert(a, _ as 1|3)
]])

run([[
    local type function Exclude(T, U)
        T:RemoveType(U)
        return T
    end

    local a: Exclude<|1|2|3, 2|>

    type_assert(a, _ as 11|31)
]], "expected 11 | 31 got 1 | 3")


test("pairs loop", function()
    run[[
        local tbl = {4,5,6}
        local k, v = 0, 0
        
        for key, val in pairs(tbl) do
            k = k + key
            v = v + val
        end

        type_assert(k, 6)
        type_assert(v, 15)
    ]]
end)

test("type functions should return a tuple with types", function()
    local analyzer = run([[
        local type test = function()
            return 1,2,3
        end

        local type a,b,c = test()
    ]])

    equal(1, analyzer:GetLocalOrEnvironmentValue("a", "typesystem"):GetData())
    equal(2, analyzer:GetLocalOrEnvironmentValue("b", "typesystem"):GetData())
    equal(3, analyzer:GetLocalOrEnvironmentValue("c", "typesystem"):GetData())
end)

run[[
    local function build_numeric_for(tbl)
        local lua = {}
        table.insert(lua, "local sum = 0")
        table.insert(lua, "for i = " .. tbl.init .. ", " .. tbl.max .. " do")
        table.insert(lua, tbl.body)
        table.insert(lua, "end")
        table.insert(lua, "return sum")
        return load(table.concat(lua, "\n"), tbl.name)
    end
    
    local func = build_numeric_for({
        name = "myfunc",
        init = 1,
        max = 10,
        body = "sum = sum + i"
    })
    
    type_assert(func(), 55)
]]

run([[
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
        body = "sum = sum + i CHECKME"
    })
]], "CHECKME")

run[[
    local a = {"1", "2", "3"}
    type_assert(table.concat(a), "123")
]]

run[[
    local a = {"1", "2", "3", _ as string}
    type_assert(table.concat(a), _ as string)
]]

run[[
    local type function mutate_table(tbl: {[any] = any})
        tbl:Set("foo", "bar")
    end
    
    local a = {}
    
    mutate_table(a)
    
    type_assert(a.foo, "bar")    
]]

run[[
    local type function mutate_table(tbl: out {[any] = any})
        tbl:Set("foo", "bar")
    end
    
    local a = {}
    
    if maybe then
        mutate_table(a)
    end
    
    type_assert(a.foo, _ as "bar" | nil)
]]

run[[
    local a = {
        b = {
            foo = true,
            bar = false,
            faz = 1,
        }
    }
    
    type_assert(_ as keysof<|typeof a.b|>, _ as "bar" | "faz" | "foo")
]]

run[[
    local function foo<|a: any, b: any|>
        return a, b
    end

    local x, y = foo<|1, 2|>
    type_assert(x, 1)
    type_assert(y, 2)
]]

run[[
    for str in ("lol1\nlol2\nlol3\n"):gmatch("(.-)\n") do
        if str ~= "lol1" and str ~= "lol2" and str ~= "lol3" then
            type_error(str)
        end
    end
]]


run[[
    -- test's scope should be from where the function was made

    local type lol = 2

    local type function test()
        assert(env.typesystem.lol:GetType():GetData() == 2)
    end

    do
        local type lol = 1
        test()
    end
]]

run[[
    local function lol(x)
        type_assert(x, 1)
    end
    
    local x: 1 | "STRING"
    local z = x == 1 and lol(x)
]]

run[[
    local function lol(x)
        type_assert(x, _ as 1 | "STRING")
    end
    
    local x: 1 | "STRING"
    local a = x == 1
    local z = lol(x)
]]

run[[
    local x: 1.5 | "STRING"
    local y = type(x) == "number" and math.ceil(x)
    type_assert(y, _ as 2 | false)
]]

run[[
    local str, count = string.gsub("hello there!", "hello", "hi")
    type_assert<|str, "hi there!"|>
    type_assert<|count, 1|>
]]

do
    _G.TEST_DISABLE_ERROR_PRINT = true
    run[[
        local function test(x)
            error("LOL")
            return "foo"
        end
        local ok, err = pcall(test, "foo")
        type_assert<|ok, false|>
        type_assert<|err, "LOL"|>


        local function test(x)
            return "foo"
        end
        local ok, err = pcall(test, "foo")
        type_assert<|ok, true|>
        type_assert<|err, "foo"|>
    ]]
    _G.TEST_DISABLE_ERROR_PRINT = false
end


do
    _G.TEST_DISABLE_ERROR_PRINT = true
    run[[
        local ok, table_new = pcall(require, "lol")
        if not ok then
            table_new = "ok"
        end

        type_assert(ok, false)
        type_assert(table_new, "ok")
    ]]
    _G.TEST_DISABLE_ERROR_PRINT = false
end
run[[
    local tbl = {
        foo = true,
        bar = false,
        faz = 1
    }
    table.sort(tbl, function(a, b) end)
]]

run[[
    local META = {}
    META.__index = META
    META.MyField = true

    local function extend(tbl: {
        __index = self,
        MyField = boolean,
        [string] = any,
    })
        tbl.ExtraField = 1
    end

    extend(META)

    type_assert(META.ExtraField, 1)
]]

run[[
    local type Entity = {
        GetChildBones = (function(string, number): {[number] = number}),
        GetBoneCount = (function(self): number),
    }
    
    local e = _ as Entity
    type_assert(e:GetBoneCount(), _ as number)
]]

run[[
    local lol = {}
    type lol.rofl = function(number, string): string
        
    function lol.rofl(a, b)
        type_assert(a, _ as number)
        type_assert(b, _ as string)
        return ""
    end
]]

run[[
    local function test(a: const string)
        return a:lower()
    end
    
    local str = test("Foo")
    type_assert(str, "foo")
]]