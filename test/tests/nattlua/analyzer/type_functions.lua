local LString = require("nattlua.types.string").LString

do
	local analyzer = analyze([[
            -- should return a tuple with types
            local type test = function()
                return 1,2,3
            end

            local a,b,c = test()
        ]])
	equal(1, analyzer:GetLocalOrGlobalValue(LString("a")):GetData())
	equal(2, analyzer:GetLocalOrGlobalValue(LString("b")):GetData())
	equal(3, analyzer:GetLocalOrGlobalValue(LString("c")):GetData())
end

analyze(
	-- should be able to error
	[[
        local type test = function()
            error("test")
        end

        test()
    ]],
	"test"
)
analyze([[
        -- exclude analyzer function
        local analyzer function Exclude(T: any, U: any)
            T:RemoveType(U)
            return T
        end

        local a: Exclude<|1|2|3, 2|>

        attest.equal(a, _ as 1|3)
    ]])
analyze(
	[[
        local analyzer function Exclude(T: any, U: any)
            T:RemoveType(U)
            return T
        end

        local a: Exclude<|1|2|3, 2|>

        attest.equal(a, _ as 11|31)
    ]],
	"expected 11 | 31 got 1 | 3"
)
analyze[[
        -- self referenced type tables
        local type a = {
            b = self,
        }
        attest.equal(a, a.b)
    ]]
analyze[[
        -- next
        local t = {k = 1}
        local a = 1
        local k,v = next({k = 1})
        attest.equal(k, nil as "k")
        attest.equal(v, nil as 1)
    ]]
analyze[[
        local k,v = next({foo = 1})
        attest.equal(string.len(k), _ as 3)
        attest.equal(v, _ as 1)
    ]]
analyze[[
        -- math.floor
        attest.equal(math.floor(1.5), 1)
    ]]
analyze([[
        -- assert
        attest.truthy(1 == 2, "lol")
    ]], "lol")

do -- require should error when not finding a module
	_G.TEST_DISABLE_ERROR_PRINT = true
	local a = analyze([[require("adawdawddwaldwadwadawol")]])
	assert(a:GetDiagnostics()[1].msg:find("not found"))
	_G.TEST_DISABLE_ERROR_PRINT = false
end

analyze[[
        -- rawset rawget
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
analyze[[
        -- select
        attest.equal(select("#", 1,2,3), 3)
    ]]
analyze[[
        -- parenthesis around vararg
        local a = select(2, 1,2,3)
        attest.equal(a, 2)
        attest.equal((select(2, 1,2,3)), 2)
    ]]
analyze[[
        -- varargs
    local type test = function(...) end
    local a = {}
    a[1] = true
    a[2] = false
    test(test(a))

    ]]
analyze[[
        -- exlcude
        local analyzer function Exclude(T: any, U: any)
            T:RemoveType(U)
            return T
        end

        local a: Exclude<|1|2|3, 2|>
        attest.equal(a, _ as 1|3)
    ]]
analyze[[
        -- table.insert
        local a = {}
        a[1] = true
        a[2] = false
        table.insert(a, 1337)
        attest.equal(a[3], 1337)
    ]]
analyze[[
        -- string sub on union
        local lol: "foo" | "bar"

        attest.equal(lol:sub(1,1), _ as "f" | "b")
        attest.equal(lol:sub(_ as 2 | 3), _ as "ar" | "o" | "oo" | "r")
    ]]

analyze[[
    local analyzer function F(a: string, b: string, c: nil | number, d: false | nil | true)
        assert(a ~= nil)
    end


    F(_ as "1976-W01-1 12:12:12.123" | string, _ as any, _ as 24 | number)
]]
do
	_G.test_var = 0
	analyze[[
        
        local analyzer function test(foo: number)
            -- when defined as number the function should be called twice for each number in the union
            
            _G.test_var = _G.test_var + 1
        end
        
        test(_ as 1 | 2)
    ]]
	assert(_G.test_var == 2)
	_G.test_var = 0
	analyze[[
        
        local analyzer function test(foo: any)
            -- when defined as anything, or no type it should just pass the union directly

            _G.test_var = _G.test_var + 1
        end
        
        test(_ as 1 | 2)
    ]]
	assert(_G.test_var == 1)
	_G.test_var = 0
	analyze[[
        
        local analyzer function test(foo: number | nil)
            -- if the only type added to the union is nil it should still be called twice
            _G.test_var = _G.test_var + 1
        end
        
        test(_ as 1 | 2)
    ]]
	assert(_G.test_var == 2)
	_G.test_var = nil
end

analyze[[
    local ok, err = attest.pcall(function()
        attest.equal(1, 2)
        return 1
    end)

    attest.equal(ok, false)
    attest.superset_of(_ as string, err)
]]
analyze[[
    local ok, val = attest.pcall(function() return 1 end)
    
    attest.equal(ok, true)
    attest.equal(val, 1)
]]
analyze([[
    local analyzer function Exclude(T: any, U: any)
        T:RemoveType(U)
        return T:Copy()
    end

    local a: Exclude<|1|2|3, 2|>

    attest.equal(a, _ as 1|3)
]])
analyze(
	[[
    local analyzer function Exclude(T: any, U: any)
        T:RemoveType(U)
        return T:Copy()
    end

    local a: Exclude<|1|2|3, 2|>

    attest.equal(a, _ as 11|31)
]],
	"expected 11 | 31 got 1 | 3"
)
analyze[[
        --pairs loop
        local tbl = {4,5,6}
        local k, v = 0, 0
        
        for key, val in pairs(tbl) do
            k = k + key
            v = v + val
        end

        attest.equal(k, 6)
        attest.equal(v, 15)
    ]]
analyze[[
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
analyze(
	[[
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
]],
	"CHECKME"
)
analyze[[
    local a = {"1", "2", "3"}
    attest.equal(table.concat(a), "123")
]]
analyze[[
    local a = {"1", "2", "3", _ as string}
    attest.equal(table.concat(a), _ as string)
]]
analyze[[
    local a = {
        b = {
            foo = true,
            bar = false,
            faz = 1,
        }
    }
    
    attest.equal(_ as keysof<|typeof a.b|>, _ as "bar" | "faz" | "foo")
]]
analyze[[
    local function foo<|a: any, b: any|>
        return a, b
    end

    local x, y = foo<|1, 2|>
    attest.equal(x, 1)
    attest.equal(y, 2)
]]
analyze[[
    for str in ("lol1\nlol2\nlol3\n"):gmatch("(.-)\n") do
        if str ~= "lol1" and str ~= "lol2" and str ~= "lol3" then
            type_error(str)
        end
    end
]]
analyze[[
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
analyze[[
    local function lol(x)
        attest.equal(x, 1)
    end
    
    local x: 1 | "STRING"
    local z = x == 1 and lol(x)
]]
analyze[[
    local function lol(x)
        attest.equal(x, _ as 1 | "STRING")
    end
    
    local x: 1 | "STRING"
    local a = x == 1
    local z = lol(x)
]]
analyze[[
    local x: 1.5 | "STRING"
    local y = type(x) == "number" and math.ceil(x)
    attest.equal(y, _ as 2 | false)
]]
analyze[[
    local str, count = string.gsub("hello there!", "hello", "hi")
    attest.equal<|str, "hi there!"|>
    attest.equal<|count, 1|>
]]
analyze[[
    local str = "";
    ("hello world"):gsub(".", function(c: ref string) 
        str = str .. c 
    end)
    attest.equal(str, "hello world")
]]

do
	_G.TEST_DISABLE_ERROR_PRINT = true
	analyze[[
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
	analyze[[
        local ok, test = pcall(require, "lol")
        if not ok then
            test = "ok"
        end

        attest.equal(ok, false)
        attest.equal(test, "ok")
    ]]
	analyze[[
        local ok, err = pcall(function() assert(false, "LOL") end)

        attest.equal(ok, false)
        attest.equal(err, "LOL")
    ]]
	_G.TEST_DISABLE_ERROR_PRINT = false
end

analyze(
	[[
    local tbl = {
        foo = true,
        bar = false,
        faz = 1
    }
    table.sort(tbl, function(a, b) end)
]],
	"foo.-is not a subset of.-number"
)
analyze[[
    local META = {}
    META.__index = META
    META.MyField = true

    local function extend(tbl: mutable ref {
        __index = self,
        MyField = boolean,
        [string] = any,
    })
        tbl.ExtraField = 1
    end

    extend(META)

    attest.equal(META.ExtraField, 1)
]]
analyze[[
    local type Entity = {
        GetChildBones = function=(string, number)>({[number] = number}),
        GetBoneCount = function=(self)>(number),
    }
    
    local e = _ as Entity
    attest.equal(e:GetBoneCount(), _ as number)
]]
analyze[[
    -- we need to say that lol has a contract so that we can mutate it
    local lol: {} = {}
    type lol.rofl = function=(number, string)>(string)
        
    function lol.rofl(a, b)
        attest.equal(a, _ as number)
        attest.equal(b, _ as string)
        return ""
    end
]]
analyze[[
    local function test(a: ref string)
        return a:lower()
    end
    
    local str = test("Foo")
    attest.equal(str, "foo")
]]
analyze[[
    local i = 0
    local function test(x: ref (string | nil))
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
analyze[[
    local a,b,c,d =  string.byte(_ as string, _ as number, _ as number)
    
    attest.equal<|a, 0..255|>
    attest.equal<|b, 0..255|>
    attest.equal<|c, 0..255|>
    attest.equal<|d, 0..255|>
]]
analyze[[
    local a,b,c,d =  string.byte("foo", 1, 2)
    attest.equal(a, 102)
    attest.equal(b, 111)
    attest.equal(c, nil)
]]
analyze[[
    local a,b,c,d =  string.byte(_ as string, 1, 2)
    attest.equal(a, _ as 0..255)
    attest.equal(b, _ as 0..255)
    attest.equal(c, nil)
    attest.equal(d, nil)
]]
analyze[[
    local function clamp(n: ref number, low: ref number, high: ref number) 
        return math.min(math.max(n, low), high) 
    end

    attest.equal(clamp(5, 7, 10), 7)
    attest.equal(clamp(15, 7, 10), 10)
]]
analyze[[
    local x: cdata

    attest.equal(type(x), "cdata")
]]
analyze[[
    local ok, err = pcall(require, "foo")
    attest.equal(ok, _ as true | false)
    if type(err) == "string" then
        attest.equal(err:sub(-9), "not found")
    end
]]
analyze[[
    local a, b = load("" as string)
    attest.equal(a, _ as nil | Function)
    attest.equal(b, _ as nil | string)
]]
analyze[[
    local type tl = {x=1337}

    do
        PushTypeEnvironment<|tl|>
        type foo = 1
        PopTypeEnvironment<||>
        type bar = 2
    end

    attest.equal(tl, {x=1337, foo=1})
    attest.equal(bar, 2)
]]
analyze[[
    local type tl = {x=1337}

    do
        PushTypeEnvironment<|tl|>
        type foo = 1
        local type lol = {}
        do
            PushTypeEnvironment<|lol|>
            type bar = 2
            PopTypeEnvironment<||> 
        end
        type x = lol
        PopTypeEnvironment<||>
    end

    attest.equal<|tl, {
        x=1337,
        foo = 1,
        x={bar=2}
    }|>
]]
analyze[[
    local ok, err = _ as any | nil, _ as any | nil | string
    attest.equal(assert(ok, err), _ as any)
]]
analyze[[
    type f = Function

    local a, b, c = xpcall(f, f, 1,2,3)
    attest.equal(a, _ as boolean)
    attest.equal(b, _ as any)
    attest.equal(c, _ as any)

    local a, b, c = pcall(f, 1,2,3)
    attest.equal(a, _ as boolean)
    attest.equal(b, _ as any)
    attest.equal(c, _ as any)
]]
analyze[[
    local function AddSymbols(tbl: List<|string|>)
        for k,v in pairs(tbl) do
            attest.equal(k, _ as number)
            attest.equal(v, _ as string)
        end
    end
    
    local t: {[1] = nil | string} = {"hello"}
    AddSymbols(t)
]]
analyze[[
    local range = math.random(1, 5)
    attest.equal(range, _  as 1 .. 5)
]]
analyze[[

local analyzer function test(...: ...any)
    assert(select("#", ...) == 3)
end 
    local x = _ as nil | true
    local y = _ as nil | true
    local z = _ as nil | true

    test(x, y, z)
]]
analyze([[

	local function read<|a: any|> end

	read(1, 2)
]], "2 is not a subset of")
analyze(
	[[

	local function read<|...: number|>
		print(...)
	end

	read(1, 2)
]],
	"2 does not exist"
)
analyze[[

	local function read<|...: ...number|>
		local x, y = ...
		attest.equal(x, 1)
		attest.equal(y, 2)
		local z = ...
		attest.equal(z, _ as (1, 2))
	end

	read(1, 2)
]]
analyze[[
    local function read<|...: ...$"%**[Lanl].*" | number|>
        local out = {}

        for i = 1, select("#", ...) do
            local v = ...[i]

            if type(v) == "number" then
                out[i] = number
            else
                out[i] = string
            end
        end

        return table.unpack(out)
    end

    local x, y, z, w = read("line", 1, 2, "all")
    attest.equal(x, _ as string)
    attest.equal(y, _ as number)
    attest.equal(z, _ as number)
    attest.equal(w, _ as string)
]]
analyze[[
    
    local function read2<|...: ...$"%**[Lanl].*" | number|>
	§print(env.typesystem["..."].tr)
	local out = {}

	for i = 1, select("#", ...) do
		local v = ...[i]

		if type(v) == "number" then
			out[i] = number
		else
			out[i] = string
		end
	end

	return table.unpack(out)
end

local function read<|...: ...any|>
	return read2<|...|>
end

local x, y, z, w = read("line", 1, 2, "all")
attest.equal(x, _ as string)
attest.equal(y, _ as number)
attest.equal(z, _ as number)
attest.equal(w, _ as string)
    ]]
analyze[[
    
    local f = assert(io.open("test", "r"))

attest.equal(f:read("*no"), _ as nil | number)
attest.equal(f:read("n"), _ as nil | number)
attest.equal(f:read("number"), _ as nil | number)

attest.expect_diagnostic("error", "NOPE.+is not a subset of")
f:read("NOPE")
]]
analyze[[

local function BooleanResult<|success: any, error: any|>
	return (true, success) | (false, error)
end

local function ValueOrError<|value: any, error: any|>
	return value | (false, error)
end

local type testA = function=()>(BooleanResult<|number, string|>)
local x, y = testA()
attest.equal(x, true as boolean)
attest.equal(y, 42 as number | string)
local type testC = function=()>(ValueOrError<|number, string|>)
local x, y = testC()
attest.equal(x, 42 as number | false)
attest.equal(y, "error" as string | nil)

]]

analyze[[
local luadata = {}
luadata.Types = {}

function luadata.SetModifier(type: string, callback: function=(string, number)>(string))
	luadata.Types[type] = callback
end
luadata.SetModifier("test", function(x)
	attest.equal(x, _ as string)
	return tostring(x)
end)
]]

analyze[[
attest.expect_diagnostic("error", "assertion failed!")
local a = assert(false)
error("NEVER")
]]

analyze[[
attest.expect_diagnostic("error", "hello")
local a, b, c = assert(false, "hello", 3)
error("NEVER")
]]
analyze[[
local a, b, c = assert(1, 2, 3)
attest.equal(a, 1)
attest.equal(b, 2)
attest.equal(c, 3)
]]

analyze[[
local a, b, c = assert(_ as boolean, 2, 3)
attest.equal(a, true)
attest.equal(b, 2)
attest.equal(c, 3)
]]

analyze[[
local a, b, c = assert(_ as boolean, 2, 3)
attest.equal(a, true)
attest.equal(b, 2)
attest.equal(c, 3)
]]

analyze[[
local analyzer function test(...: ...any)  
    local a,b,c = ...
    assert(a.Type == "any")
    assert(not b)
    assert(not c)
end

local type F = function=()>(...any)

test(F())
]]