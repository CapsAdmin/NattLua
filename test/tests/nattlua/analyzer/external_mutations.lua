analyze([[
    local x = {foo = true}

    Any()(x)

    attest.equal<|x.foo, any | true|>
]])
analyze[[
    local analyzer function unknown(tbl: {[any] = any} | {} )
        tbl:Set(types.ConstString("foo"), types.ConstString("bar"))
    end
    
    local x = {}
    
    unknown(x)
    
    attest.equal(x.foo, "bar")    
]]
pending[[
    local function string_mutator<|tbl: {[any] = any}|>
        for key, val in pairs(tbl) do
            tbl[key] = nil
        end
        tbl[string] = string
    end
        
    local a = {foo = true}
    
    if math.random() > 0.5 then
        string_mutator(a)
        attest.equal<|a, {[string] = string}|>
    end
    
    attest.equal<|a, {foo = true} | {[string] = string}|>
]]
analyze[[
    local function mutate_table(tbl: ref {foo = number})
        if math.random() > 0.5 then
            tbl.foo = 2
        end
    end
    
    local tbl = {}
    
    tbl.foo = 1
    
    mutate_table(tbl)
    
    attest.equal(tbl.foo, _ as 1 | 2)
]]
analyze[[
    local function mutate_table(tbl: ref {foo = number})
        tbl.foo = 2
    end

    local tbl = {}

    tbl.foo = 1

    mutate_table(tbl)

    attest.equal(tbl.foo, 2)
]]
analyze(
	[[
    local function mutate_table(tbl: Immutable<|{lol = number}|>)
        tbl.lol = 1
    end
    
    local tbl = {lol = 2}
    
    mutate_table(tbl)
    
    attest.equal(tbl.lol, 2)
]],
	"immutable"
)
analyze([[
    local function mutate_table(tbl: ref {lol = number})
        tbl.lol = 1
    end
    
    local tbl = {lol = 2}
    
    mutate_table(tbl)
    
    attest.equal(tbl.lol, 1)
]])
analyze([[
    local function mutate_table(tbl: ref {lol = number})
        tbl.lol = 1
    end
    
    local tbl = {}
    
    tbl.lol = 2

    mutate_table(tbl)
    
    attest.equal(tbl.lol, 1)

    §assert(not analyzer:GetDiagnostics()[1])
]])
analyze[[
    local function mutate_table(tbl: ref {foo = number})
        if math.random() > 0.5 then
            tbl.foo = 2
            attest.equal<|typeof tbl.foo, 2|>
        end
        attest.equal<|typeof tbl.foo, 1 | 2|>
    end
    
    local tbl = {}
    
    tbl.foo = 1
    
    mutate_table(tbl)
    
    attest.equal<|typeof tbl.foo, 1 | 2|>
]]
analyze[[
    §analyzer.config.external_mutation = true
    
    local type func = function=(number, {[string] = boolean}, number)>(nil)

    local test = {foo = true}
    
    func(1, test, 2)
    §assert(analyzer:GetDiagnostics()[1].msg:find("can be mutated by external call"))
]]
analyze[[
    local tbl = {} as {foo = number | nil}

    if tbl.foo then
        attest.equal(tbl.foo, _ as number)
    end
]]
analyze[[
    local function foo(x: {value = string})
        attest.equal<|typeof x.value, string|>
    end

    foo({value = "test"})
]]
analyze[[
    local function foo(x: ref {value = string})
        attest.equal<|typeof x.value, "test"|>
    end

    foo({value = "test"})
]]
analyze[[
    local function test(value: {foo = number | nil})
        if value.foo then
            attest.equal(value.foo, _ as number)
        end
    end
    
    test({foo = 4})
]]
analyze[[
    local function test(value: {foo = number | nil})
        if value.foo then
            attest.equal(value.foo, _ as number)
        end
    end
    
]]
analyze[[
    local function mutate(tbl: ref {foo = number, [string] = any})
        tbl.lol = true
        tbl.foo = 3
    end
    
    local tbl = {foo = 1}
    
    attest.equal(tbl.foo, 1)
    
    tbl = {foo = 2}
    
    attest.equal(tbl.foo, 2)
    
    mutate(tbl)
    
    attest.equal(tbl.foo, 3)
    attest.equal(tbl.lol, true)
    
    tbl = {foo = 4}
    
    attest.equal(tbl.foo, 4)
]]
analyze[[
    local t = {lol = "lol"}

    ;(function(val: ref {[string] = string})
        val.foo = "foo"
        ;(function(val: ref {[string] = string})
            val.bar = "bar"
            ;(function(val: ref {[string] = string})
                val.faz = "faz"
                val.lol = "ROFL"
            end)(val)
        end)(val)
    end)(t)
    
    attest.equal(t, {
        foo = "foo",
        bar = "bar",
        faz = "faz",
        lol = "ROFL",
    })
]]
analyze[[
    local function string_mutator<|tbl: {[any] = any}|>
        for key, val in pairs(tbl) do
            tbl[key] = nil
        end
        tbl[string] = string
    end
        
    local a = {foo = true}
    
    string_mutator(a)
    
    attest.equal<|a.foo, string|>
    attest.equal(a.foo, true)
]]
analyze[[
    local function string_mutator<|tbl: ref {[any] = any}|>
        for key, val in pairs(tbl) do
            tbl[key] = nil
        end

        tbl[string] = string
    end

    local a = {foo = true}
    string_mutator(a)
    attest.equal<|a.foo, string|>
    attest.equal<|a.bar, string|>
]]
-- nested non-ref calls: inner call must not clobber outer's contract
analyze[[
    local function inner(tbl: {foo = number, bar = number})
        attest.equal<|typeof tbl.foo, number|>
        attest.equal<|typeof tbl.bar, number|>
    end

    local function outer(tbl: {foo = number})
        attest.equal<|typeof tbl.foo, number|>
        inner(tbl)
        attest.equal<|typeof tbl.foo, number|>
    end

    local tbl = {foo = 1, bar = 2}
    outer(tbl)
    attest.equal(tbl.foo, 1)
    attest.equal(tbl.bar, 2)
]]
-- same table passed as two different arguments
analyze[[
    local function takes_two(a: {x = number}, b: {x = number})
        attest.equal<|typeof a.x, number|>
        attest.equal<|typeof b.x, number|>
    end

    local tbl = {x = 1}
    takes_two(tbl, tbl)
    attest.equal(tbl.x, 1)
]]
-- non-ref mutations must not leak back to caller
analyze[[
    local function modify(tbl: {val = number})
        tbl.val = 999
    end

    local tbl = {val = 1}
    modify(tbl)
    attest.equal(tbl.val, 1)
]]
-- ref vs non-ref on same table in sequence
analyze[[
    local function no_ref(tbl: {val = number})
        tbl.val = 50
    end

    local function with_ref(tbl: ref {val = number})
        tbl.val = 100
    end

    local tbl = {val = 1}
    no_ref(tbl)
    attest.equal(tbl.val, 1)
    with_ref(tbl)
    attest.equal(tbl.val, 100)
]]
-- recursive function: contract stack grows and unwinds with recursion
analyze[[
    local function recurse(tbl: {count = number}, depth: number)
        if depth > 0 then
            recurse(tbl, depth - 1)
        end
        attest.equal<|typeof tbl.count, number|>
    end

    local tbl = {count = 0}
    recurse(tbl, 3)
    attest.equal(tbl.count, 0)
]]
-- non-ref table with return type check
analyze[[
    local function transform(tbl: {x = number}): number
        return tbl.x + 1
    end

    local tbl = {x = 5}
    local result = transform(tbl)
    attest.equal<|typeof result, number|>
    attest.equal(tbl.x, 5)
]]
