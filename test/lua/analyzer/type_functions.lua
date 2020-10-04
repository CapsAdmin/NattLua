local T = require("test.helpers")
local run = T.RunCode

test("should return a tuple with types", function()
    local analyzer = run([[
        local type test = function()
            return 1,2,3
        end

        local type a,b,c = test()
    ]])

    equal(1, analyzer:GetEnvironmentValue("a", "typesystem"):GetData())
    equal(2, analyzer:GetEnvironmentValue("b", "typesystem"):GetData())
    equal(3, analyzer:GetEnvironmentValue("c", "typesystem"):GetData())
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
            T:RemoveElement(U)
            return T
        end

        local a: Exclude<|1|2|3, 2|>

        type_assert(a, _ as 1|3)
    ]])

    run([[
        local type function Exclude(T, U)
            T:RemoveElement(U)
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

test("require should error when not finding a module", function()
    run([[require("adawdawddwaldwadwadawol")]], "unable to find module")
end)

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
            T:RemoveElement(U)
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

test("string sub on set", function()
    run[[
        local lol: "foo" | "bar"

        type_assert(lol:sub(1,1), _ as "f" | "b")
    ]]
end)

run[[
    local a = {1,2,3}

    local type type_pcall = function(func, ...) 
        return pcall(self.Call, self, func, types.Tuple({...}))
    end

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
        T:RemoveElement(U)
        return T
    end

    local a: Exclude<|1|2|3, 2|>

    type_assert(a, _ as 1|3)
]])

run([[
    local type function Exclude(T, U)
        T:RemoveElement(U)
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

    equal(1, analyzer:GetEnvironmentValue("a", "typesystem"):GetData())
    equal(2, analyzer:GetEnvironmentValue("b", "typesystem"):GetData())
    equal(3, analyzer:GetEnvironmentValue("c", "typesystem"):GetData())
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