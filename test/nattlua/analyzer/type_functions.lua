local T = require("test.helpers")
local run = T.RunCode
local String = T.String

test("should return a tuple with types", function()
    local analyzer = run([[
        local type test = function()
            return 1,2,3
        end

        local a,b,c = test()
    ]])

    equal(1, analyzer:GetLocalOrEnvironmentValue(String("a"), "runtime"):GetData())
    equal(2, analyzer:GetLocalOrEnvironmentValue(String("b"), "runtime"):GetData())
    equal(3, analyzer:GetLocalOrEnvironmentValue(String("c"), "runtime"):GetData())
end)

test("should be able to error", function()
    run([[
        local type test = function()
            error("test")
        end

        test()
    ]], "test")
end)

test("exclude analyzer function", function()
    run([[
        local analyzer function Exclude(T: any, U: any)
            T:RemoveType(U)
            return T
        end

        local a: Exclude<|1|2|3, 2|>

        types.assert(a, _ as 1|3)
    ]])

    run([[
        local analyzer function Exclude(T: any, U: any)
            T:RemoveType(U)
            return T
        end

        local a: Exclude<|1|2|3, 2|>

        types.assert(a, _ as 11|31)
    ]], "expected 11 | 31 got 1 | 3")
end)

test("self referenced type tables", function()
    run[[
        local type a = {
            b = self,
        }
        types.assert(a, a.b)
    ]]
end)

test("next", function()
    run[[
        local t = {k = 1}
        local a = 1
        local k,v = next({k = 1})
        types.assert(k, nil as "k" | "k")
        types.assert(v, nil as 1 | 1)
    ]]
    run[[
        local k,v = next({foo = 1})
        types.assert(string.len(k), _ as 3 | 3)
        types.assert(v, _ as 1 | 1)
    ]]
end)

test("math.floor", function()
    run[[
        types.assert(math.floor(1.5), 1)
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
        types.assert(rawget(self, "lol"), "LOL")
        types.assert(called, false)
    ]]
end)

test("select", function()
    run[[
        types.assert(select("#", 1,2,3), 3)
    ]]
end)

test("parenthesis around vararg", function()
    run[[
        local a = select(2, 1,2,3)
        types.assert(a, 2)
        types.assert((select(2, 1,2,3)), 2)
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
        local analyzer function Exclude(T: any, U: any)
            T:RemoveType(U)
            return T
        end

        local a: Exclude<|1|2|3, 2|>
        types.assert(a, _ as 1|3)
    ]]
end)

test("table.insert", function()
    run[[
        local a = {}
        a[1] = true
        a[2] = false
        table.insert(a, 1337)
        types.assert(a[3], 1337)
    ]]
end)

test("string sub on union", function()
    run[[
        local lol: "foo" | "bar"

        types.assert(lol:sub(1,1), _ as "f" | "b")
        types.assert(lol:sub(_ as 2 | 3), _ as "ar" | "o" | "oo" | "r")
    ]]
end)

do 
    _G.test_var = 0
    run[[
        
        local analyzer function test(foo: number)
            -- when defined as number the function should be called twice for each number in the union
            
            _G.test_var = _G.test_var + 1
        end
        
        test(_ as 1 | 2)
    ]]
    assert(_G.test_var == 2)

    _G.test_var = 0
    run[[
        
        local analyzer function test(foo: any)
            -- when defined as anything, or no type it should just pass the union directly

            _G.test_var = _G.test_var + 1
        end
        
        test(_ as 1 | 2)
    ]]
    assert(_G.test_var == 1)

    _G.test_var = 0
    run[[
        
        local analyzer function test(foo: number | nil)
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
        types.assert(1, 2)
        return 1
    end)

    types.assert(ok, false)
    types.assert_superset(err, _ as string)
]]

run[[
    local ok, val = type_pcall(function() return 1 end)
    
    types.assert(ok, true)
    types.assert(val, 1)
]]

run([[
    local analyzer function Exclude(T: any, U: any)
        T:RemoveType(U)
        return T:Copy()
    end

    local a: Exclude<|1|2|3, 2|>

    types.assert(a, _ as 1|3)
]])

run([[
    local analyzer function Exclude(T: any, U: any)
        T:RemoveType(U)
        return T:Copy()
    end

    local a: Exclude<|1|2|3, 2|>

    types.assert(a, _ as 11|31)
]], "expected 11 | 31 got 1 | 3")


test("pairs loop", function()
    run[[
        local tbl = {4,5,6}
        local k, v = 0, 0
        
        for key, val in pairs(tbl) do
            k = k + key
            v = v + val
        end

        types.assert(k, 6)
        types.assert(v, 15)
    ]]
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
    
    types.assert(func(), 55)
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
    types.assert(table.concat(a), "123")
]]

run[[
    local a = {"1", "2", "3", _ as string}
    types.assert(table.concat(a), _ as string)
]]

run[[
    local a = {
        b = {
            foo = true,
            bar = false,
            faz = 1,
        }
    }
    
    types.assert(_ as keysof<|typeof a.b|>, _ as "bar" | "faz" | "foo")
]]

run[[
    local function foo<|a: any, b: any|>
        return a, b
    end

    local x, y = foo<|1, 2|>
    types.assert(x, 1)
    types.assert(y, 2)
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

    local analyzer function test()
        assert(env.typesystem.lol:GetData() == 2)
    end

    do
        local type lol = 1
        test()
    end
]]

run[[
    local function lol(x)
        types.assert(x, 1)
    end
    
    local x: 1 | "STRING"
    local z = x == 1 and lol(x)
]]

run[[
    local function lol(x)
        types.assert(x, _ as 1 | "STRING")
    end
    
    local x: 1 | "STRING"
    local a = x == 1
    local z = lol(x)
]]

run[[
    local x: 1.5 | "STRING"
    local y = type(x) == "number" and math.ceil(x)
    types.assert(y, _ as 2 | false)
]]

run[[
    local str, count = string.gsub("hello there!", "hello", "hi")
    types.assert<|str, "hi there!"|>
    types.assert<|count, 1|>
]]

do
    _G.TEST_DISABLE_ERROR_PRINT = true
    run[[
        local function test(x)
            error("LOL")
            return "foo"
        end
        local ok, err = pcall(test, "foo")
        types.assert<|ok, false|>
        types.assert<|err, "LOL"|>


        local function test(x)
            return "foo"
        end
        local ok, err = pcall(test, "foo")
        types.assert<|ok, true|>
        types.assert<|err, "foo"|>
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

        types.assert(ok, false)
        types.assert(table_new, "ok")
    ]]
    run[[
        local ok, err = pcall(function() assert(false, "LOL") end)

        types.assert(ok, false)
        types.assert(err, "LOL")
    ]]
    _G.TEST_DISABLE_ERROR_PRINT = false
end
run([[
    local tbl = {
        foo = true,
        bar = false,
        faz = 1
    }
    table.sort(tbl, function(a, b) end)
]], "1%.%.inf.-has no field")

run[[
    local META = {}
    META.__index = META
    META.MyField = true

    local function extend(tbl: mutable {
        __index = self,
        MyField = boolean,
        [string] = any,
    })
        tbl.ExtraField = 1
    end

    extend(META)

    types.assert(META.ExtraField, 1)
]]

run[[
    local type Entity = {
        GetChildBones = function=(string, number)>({[number] = number}),
        GetBoneCount = function=(self)>(number),
    }
    
    local e = _ as Entity
    types.assert(e:GetBoneCount(), _ as number)
]]

run[[
    -- we need to say that lol has a contract so that we can mutate it
    local lol: {} = {}
    type lol.rofl = function=(number, string)>(string)
        
    function lol.rofl(a, b)
        types.assert(a, _ as number)
        types.assert(b, _ as string)
        return ""
    end
]]

run[[
    local function test(a: literal string)
        return a:lower()
    end
    
    local str = test("Foo")
    types.assert(str, "foo")
]]

run[[
    local i = 0
    local function test(arg: literal (string | nil))
        if i == 0 then
            types.assert<|typeof arg, "foo"|>
        elseif i == 1 then
            types.assert<|typeof arg, nil|>
        end
        i = i + 1
    end

    test("foo")
    test()
]]

run[[
    local a,b,c,d =  string.byte(_ as string, _ as number, _ as number)
    
    types.assert<|a, number|>
    types.assert<|b, number|>
    types.assert<|c, number|>
    types.assert<|d, number|>
]]

run[[
    local a,b,c,d =  string.byte("foo", 1, 2)
    types.assert(a, 102)
    types.assert(b, 111)
    types.assert(c, nil)
]]

run[[
    local a,b,c,d =  string.byte(_ as string, 1, 2)
    types.assert(a, _ as number)
    types.assert(b, _ as number)
    types.assert(c, nil)
    types.assert(d, nil)
]]
