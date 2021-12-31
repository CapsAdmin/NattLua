local T = require("test.helpers")
local run = T.RunCode

run([[
    local x: {foo = boolean} = {foo = true}

    unknown(x)
]], "cannot mutate argument")

run([[
    local x = {foo = true}

    unknown(x)

    types.assert<|x.foo, any | true|>
]])

run[[
    local analyzer function unknown(tbl: {[any] = any} | {} )
        tbl:Set(types.LString("foo"), types.LString("bar"))
    end
    
    local x = {}
    
    unknown(x)
    
    types.assert(x.foo, "bar")    
]]

run([[
    local function mutate_table(tbl: {lol = number})
        tbl.lol = 1
    end
    
    local tbl = {lol = 2}
    
    mutate_table(tbl)
    
    types.assert(tbl.lol, 1)
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
        types.assert<|a, {[string] = string}|>
    end
    
    types.assert<|a, {foo = true} | {[string] = string}|>
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
    
    types.assert(tbl.foo, _ as 1 | 2)
]]

run[[
    local function mutate_table(tbl: mutable {foo = number})
        tbl.foo = 2
    end

    local tbl = {}

    tbl.foo = 1

    mutate_table(tbl)

    types.assert(tbl.foo, 2)
]]

run([[
    local function mutate_table(tbl: {lol = number})
        tbl.lol = 1
    end
    
    local tbl = {lol = 2}
    
    mutate_table(tbl)
    
    types.assert(tbl.lol, 1)
]], "immutable contract")

run([[
    local function mutate_table(tbl: mutable {lol = number})
        tbl.lol = 1
    end
    
    local tbl = {lol = 2}
    
    mutate_table(tbl)
    
    types.assert(tbl.lol, 1)
]])

run([[
    local function mutate_table(tbl: mutable {lol = number})
        tbl.lol = 1
    end
    
    local tbl = {}
    
    tbl.lol = 2

    mutate_table(tbl)
    
    types.assert(tbl.lol, 1)

    §assert(not analyzer:GetDiagnostics()[1])
]])

run[[
    local function mutate_table(tbl: literal mutable {foo = number})
        if math.random() > 0.5 then
            tbl.foo = 2
            types.assert<|typeof tbl.foo, 2|>
        end
        types.assert<|typeof tbl.foo, 1 | 2|>
    end
    
    local tbl = {}
    
    tbl.foo = 1
    
    mutate_table(tbl)
    
    types.assert<|typeof tbl.foo, 1 | 2|>
]]

run[[
    §analyzer.config.external_mutation = true
    
    local type func = function=(number, {[string] = boolean}, number)>(nil)

    local test = {foo = true}
    
    func(1, test, 2)
    §assert(analyzer:GetDiagnostics()[1].msg:find("can be mutated by external call"))
]]

run[[
    local tbl = {} as {foo = number | nil}

    if tbl.foo then
        types.assert(tbl.foo, _ as number)
    end
]]

run[[
    local function foo(x: {value = string})
        types.assert<|typeof x.value, string|>
    end

    foo({value = "test"})
]]


run[[
    local function foo(x: literal {value = string})
        types.assert<|typeof x.value, "test"|>
    end

    foo({value = "test"})
]]

run[[
    local function test(value: {foo = number | nil})
        if value.foo then
            types.assert(value.foo, _ as number)
        end
    end
    
    test({foo = 4})
]]
run[[
    local function test(value: {foo = number | nil})
        if value.foo then
            types.assert(value.foo, _ as number)
        end
    end
    
]]

run[[
    local function mutate(tbl: mutable {foo = number, [string] = any})
        tbl.lol = true
        tbl.foo = 3
    end
    
    local tbl = {foo = 1}
    
    types.assert(tbl.foo, 1)
    
    tbl = {foo = 2}
    
    types.assert(tbl.foo, 2)
    
    mutate(tbl)
    
    types.assert(tbl.foo, 3)
    types.assert(tbl.lol, true)
    
    tbl = {foo = 4}
    
    types.assert(tbl.foo, 4)
]]

run[[
    local t = {lol = "lol"}

    ;(function(val: literal {[string] = string})
        val.foo = "foo"
        ;(function(val: literal {[string] = string})
            val.bar = "bar"
            ;(function(val: literal {[string] = string})
                val.faz = "faz"
                val.lol = "ROFL"
            end)(val)
        end)(val)
    end)(t)
    
    types.assert(t, {
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
    
    types.assert<|a.foo, string|>
    types.assert<|a.bar, string|>
]]

run[[
    local META = {}
    META.__index = META
    type META.Type = string
    type META.@Self = {}
    type BaseType = META.@Self
    
    function META.GetSet(tbl: literal any, name: literal string, default: literal any)
        tbl[name] = default as NonLiteral<|default|>
    	type tbl.@Self[name] = tbl[name] 
        tbl["Set" .. name] = function(self: tbl.@Self, val: typeof tbl[name] )
            self[name] = val
            return self
        end
        tbl["Get" .. name] = function(self: tbl.@Self): typeof tbl[name] 
            return self[name]
        end
    end
    
    do
        META:GetSet("UniqueID", nil  as nil | number)
        local ref = 0
    
        function META:MakeUnique(b: boolean)
            if b then
                §assert(env.runtime.self.mutations == nil)
                self.UniqueID = ref
                ref = ref + 1
            else
                self.UniqueID = nil
            end
    
            return self
        end
    
        function META:DisableUniqueness()
            self.UniqueID = nil
        end
    end
]]

run[[
    local META = {}
    META.__index = META
    type META.@Self = {
        Position = number,
    }
    local type Lexer = META.@Self

    function META:IsString()
        return true
    end

    local function ReadCommentEscape(lexer: Lexer & {comment_escape = boolean | nil})
        lexer:IsString()
        lexer.comment_escape = true
    end

    function META:Read()
        ReadCommentEscape(self)
    end
]]