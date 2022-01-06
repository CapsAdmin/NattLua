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

    equal(1, analyzer:GetLocalOrGlobalValue(String("a")):GetData())
    equal(2, analyzer:GetLocalOrGlobalValue(String("b")):GetData())
    equal(3, analyzer:GetLocalOrGlobalValue(String("c")):GetData())
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

        attest.equal(a, _ as 1|3)
    ]])

    run([[
        local analyzer function Exclude(T: any, U: any)
            T:RemoveType(U)
            return T
        end

        local a: Exclude<|1|2|3, 2|>

        attest.equal(a, _ as 11|31)
    ]], "expected 11 | 31 got 1 | 3")
end)

test("self referenced type tables", function()
    run[[
        local type a = {
            b = self,
        }
        attest.equal(a, a.b)
    ]]
end)

test("next", function()
    run[[
        local t = {k = 1}
        local a = 1
        local k,v = next({k = 1})
        attest.equal(k, nil as "k" | "k")
        attest.equal(v, nil as 1 | 1)
    ]]
    run[[
        local k,v = next({foo = 1})
        attest.equal(string.len(k), _ as 3 | 3)
        attest.equal(v, _ as 1 | 1)
    ]]
end)

test("math.floor", function()
    run[[
        attest.equal(math.floor(1.5), 1)
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
        attest.equal(rawget(self, "lol"), "LOL")
        attest.equal(called, false)
    ]]
end)

test("select", function()
    run[[
        attest.equal(select("#", 1,2,3), 3)
    ]]
end)

test("parenthesis around vararg", function()
    run[[
        local a = select(2, 1,2,3)
        attest.equal(a, 2)
        attest.equal((select(2, 1,2,3)), 2)
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
        attest.equal(a, _ as 1|3)
    ]]
end)

test("table.insert", function()
    run[[
        local a = {}
        a[1] = true
        a[2] = false
        table.insert(a, 1337)
        attest.equal(a[3], 1337)
    ]]
end)

test("string sub on union", function()
    run[[
        local lol: "foo" | "bar"

        attest.equal(lol:sub(1,1), _ as "f" | "b")
        attest.equal(lol:sub(_ as 2 | 3), _ as "ar" | "o" | "oo" | "r")
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
        attest.equal(1, 2)
        return 1
    end)

    attest.equal(ok, false)
    attest.superset_of(_ as string, err)
]]

run[[
    local ok, val = type_pcall(function() return 1 end)
    
    attest.equal(ok, true)
    attest.equal(val, 1)
]]

run([[
    local analyzer function Exclude(T: any, U: any)
        T:RemoveType(U)
        return T:Copy()
    end

    local a: Exclude<|1|2|3, 2|>

    attest.equal(a, _ as 1|3)
]])

run([[
    local analyzer function Exclude(T: any, U: any)
        T:RemoveType(U)
        return T:Copy()
    end

    local a: Exclude<|1|2|3, 2|>

    attest.equal(a, _ as 11|31)
]], "expected 11 | 31 got 1 | 3")


test("pairs loop", function()
    run[[
        local tbl = {4,5,6}
        local k, v = 0, 0
        
        for key, val in pairs(tbl) do
            k = k + key
            v = v + val
        end

        attest.equal(k, 6)
        attest.equal(v, 15)
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
    
    attest.equal(func(), 55)
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
    attest.equal(table.concat(a), "123")
]]

run[[
    local a = {"1", "2", "3", _ as string}
    attest.equal(table.concat(a), _ as string)
]]

run[[
    local a = {
        b = {
            foo = true,
            bar = false,
            faz = 1,
        }
    }
    
    attest.equal(_ as keysof<|typeof a.b|>, _ as "bar" | "faz" | "foo")
]]

run[[
    local function foo<|a: any, b: any|>
        return a, b
    end

    local x, y = foo<|1, 2|>
    attest.equal(x, 1)
    attest.equal(y, 2)
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
        attest.equal(x, 1)
    end
    
    local x: 1 | "STRING"
    local z = x == 1 and lol(x)
]]

run[[
    local function lol(x)
        attest.equal(x, _ as 1 | "STRING")
    end
    
    local x: 1 | "STRING"
    local a = x == 1
    local z = lol(x)
]]

run[[
    local x: 1.5 | "STRING"
    local y = type(x) == "number" and math.ceil(x)
    attest.equal(y, _ as 2 | false)
]]

run[[
    local str, count = string.gsub("hello there!", "hello", "hi")
    attest.equal<|str, "hi there!"|>
    attest.equal<|count, 1|>
]]

do
    _G.TEST_DISABLE_ERROR_PRINT = true
    run[[
        local function test(x)
            error("LOL")
            return "foo"
        end
        local ok, err = pcall(test, "foo")
        attest.equal<|ok, false|>
        attest.equal<|err, "LOL"|>


        local function test(x)
            return "foo"
        end
        local ok, err = pcall(test, "foo")
        attest.equal<|ok, true|>
        attest.equal<|err, "foo"|>
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

        attest.equal(ok, false)
        attest.equal(table_new, "ok")
    ]]
    run[[
        local ok, err = pcall(function() assert(false, "LOL") end)

        attest.equal(ok, false)
        attest.equal(err, "LOL")
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
]], "foo.-is not the same type as number")

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

    attest.equal(META.ExtraField, 1)
]]

run[[
    local type Entity = {
        GetChildBones = function=(string, number)>({[number] = number}),
        GetBoneCount = function=(self)>(number),
    }
    
    local e = _ as Entity
    attest.equal(e:GetBoneCount(), _ as number)
]]

run[[
    -- we need to say that lol has a contract so that we can mutate it
    local lol: {} = {}
    type lol.rofl = function=(number, string)>(string)
        
    function lol.rofl(a, b)
        attest.equal(a, _ as number)
        attest.equal(b, _ as string)
        return ""
    end
]]

run[[
    local function test(a: literal string)
        return a:lower()
    end
    
    local str = test("Foo")
    attest.equal(str, "foo")
]]

run[[
    local i = 0
    local function test(x: literal (string | nil))
        if i == 0 then
            attest.equal<|typeof x, "foo"|>
        elseif i == 1 then
            attest.equal<|typeof x, nil|>
        end
        i = i + 1
    end

    test("foo")
    test()
]]

run[[
    local a,b,c,d =  string.byte(_ as string, _ as number, _ as number)
    
    attest.equal<|a, number|>
    attest.equal<|b, number|>
    attest.equal<|c, number|>
    attest.equal<|d, number|>
]]

run[[
    local a,b,c,d =  string.byte("foo", 1, 2)
    attest.equal(a, 102)
    attest.equal(b, 111)
    attest.equal(c, nil)
]]

run[[
    local a,b,c,d =  string.byte(_ as string, 1, 2)
    attest.equal(a, _ as number)
    attest.equal(b, _ as number)
    attest.equal(c, nil)
    attest.equal(d, nil)
]]


run[[
    local function clamp(n: literal number, low: literal number, high: literal number) 
        return math.min(math.max(n, low), high) 
    end

    attest.equal(clamp(5, 7, 10), 7)
    attest.equal(clamp(15, 7, 10), 10)
]]