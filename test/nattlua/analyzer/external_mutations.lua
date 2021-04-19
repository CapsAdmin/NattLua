local T = require("test.helpers")
local run = T.RunCode

run([[
    local x: {foo = boolean} = {foo = true}

    unknown(x)
]], "cannot mutate argument")

run([[
    local x = {foo = true}

    unknown(x)

    type_assert<|x.foo, any | true|>
]])

run[[
    local type function unknown(tbl: {[any] = any})
        tbl:Set("foo", "bar")
    end
    
    local x = {}
    
    unknown(x)
    
    type_assert(x.foo, "bar")    
]]

run([[
    local function mutate_table(tbl: {lol = number})
        tbl.lol = 1
    end
    
    local tbl = {lol = 2}
    
    mutate_table(tbl)
    
    type_assert(tbl.lol, 1)
]], "immutable contract")


pending[[
    local function string_mutator<|tbl: mutable {[any] = any}|>
        for key, val in pairs(tbl) do
            tbl[key] = nil
        end
        tbl[string] = string
    end
        
    local a = {foo = true}
    
    if math.random() > 0.5 then
        string_mutator(a)
        type_assert<|a, {[string] = string}|>
    end
    
    type_assert<|a, {foo = true} | {[string] = string}|>
]]

run[[
    local function mutate_table(tbl: mutable {foo = number})
        if math.random() > 0.5 then
            tbl.foo = 2
        end
    end
    
    local tbl = {}
    
    tbl.foo = 1
    
    mutate_table(tbl)
    
    type_assert(tbl.foo, _ as 1 | 2)
]]

run[[
    local function mutate_table(tbl: mutable {foo = number})
        tbl.foo = 2
    end

    local tbl = {}

    tbl.foo = 1

    mutate_table(tbl)

    type_assert(tbl.foo, 2)
]]

run([[
    local function mutate_table(tbl: {lol = number})
        tbl.lol = 1
    end
    
    local tbl = {lol = 2}
    
    mutate_table(tbl)
    
    type_assert(tbl.lol, 1)
]], "immutable contract")

run([[
    local function mutate_table(tbl: mutable {lol = number})
        tbl.lol = 1
    end
    
    local tbl = {lol = 2}
    
    mutate_table(tbl)
    
    type_assert(tbl.lol, 1)
]])

run([[
    local function mutate_table(tbl: mutable {lol = number})
        tbl.lol = 1
    end
    
    local tbl = {}
    
    tbl.lol = 2

    mutate_table(tbl)
    
    type_assert(tbl.lol, 1)

    §assert(not analyzer:GetDiagnostics()[1])
]])

run[[
    local function mutate_table(tbl: literal mutable {foo = number})
        if math.random() > 0.5 then
            tbl.foo = 2
            type_assert<|typeof tbl.foo, 2|>
        end
        type_assert<|typeof tbl.foo, 1 | 2|>
    end
    
    local tbl = {}
    
    tbl.foo = 1
    
    mutate_table(tbl)
    
    type_assert<|typeof tbl.foo, 1 | 2|>
]]

run[[
    §analyzer.config.external_mutation = true
    
    local type func = function(number, {[string] = boolean}, number): nil 

    local test = {foo = true}
    
    func(1, test, 2)
    §assert(analyzer:GetDiagnostics()[1].msg:find("can be mutated by external call"))
]]

run[[
    local tbl = {} as {foo = number | nil}

    if tbl.foo then
        type_assert<|typeof tbl.foo, number|>
    end
]]

run[[
    local function foo(arg: {value = string})
        type_assert<|typeof arg.value, string|>
    end

    foo({value = "test"})
]]


run[[
    local function foo(arg: literal {value = string})
        type_assert<|typeof arg.value, "test"|>
    end

    foo({value = "test"})
]]

run[[
    local function test(value: {foo = number | nil})
        if value.foo then
            type_assert<|typeof value.foo, number|>
        end
    end
    
    test({foo = 4})
]]
run[[
    local function test(value: {foo = number | nil})
        if value.foo then
            type_assert<|typeof value.foo, number|>
        end
    end
    
]]

run[[
    local function mutate(tbl: mutable {foo = number, [string] = any})
        tbl.lol = true
        tbl.foo = 3
    end
    
    local tbl = {foo = 1}
    
    type_assert(tbl.foo, 1)
    
    tbl = {foo = 2}
    
    type_assert(tbl.foo, 2)
    
    mutate(tbl)
    
    type_assert(tbl.foo, 3)
    type_assert(tbl.lol, true)
    
    tbl = {foo = 4}
    
    type_assert(tbl.foo, 4)
]]

run[[
    local t = {lol = "lol"}

    ;(function(val: mutable {[string] = string})
        val.foo = "foo"
        ;(function(val: mutable {[string] = string})
            val.bar = "bar"
            ;(function(val: mutable {[string] = string})
                val.faz = "faz"
                val.lol = "ROFL"
            end)(val)
        end)(val)
    end)(t)
    
    type_assert(t, {
        foo = "foo",
        bar = "bar",
        faz = "faz",
        lol = "ROFL",
    })
]]

pending[[
    local function string_mutator<|tbl: mutable {[any] = any}|>
        for key, val in pairs(tbl) do
            tbl[key] = nil
        end
        tbl[string] = string
    end
        
    local a = {foo = true}
    
    string_mutator(a)
    
    type_assert<|a.foo, string|>
    type_assert<|a.bar, string|>
]]